"""
Price data service with in-memory caching and Azure Table Storage fallback.

Architecture:
1. On startup: Load all JSONL data into memory cache (O(1) lookups)
2. If Azure Table Storage is configured: Use as persistent backend
3. Fallback: Query Azure Table Storage if symbol not in local cache
"""

import json
import logging
import os
import sys
import threading
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

from dotenv import load_dotenv
from fastmcp import FastMCP

# Add parent directory to Python path to import tools module
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

load_dotenv()

mcp = FastMCP("LocalPrices")

# Ensure project root is on sys.path for absolute imports like `tools.*`
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from tools.general_tools import get_config_value

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# =============================================================================
# In-Memory Cache Implementation
# =============================================================================

# Global cache: {symbol -> {"daily": {date -> ohlcv}, "hourly": {datetime -> ohlcv}}}
_PRICE_CACHE: Dict[str, Dict[str, Dict[str, Any]]] = {}
_CACHE_LOCK = threading.Lock()
_CACHE_LOADED = False

# Azure Table Storage client (lazy initialized)
_TABLE_CLIENT = None
_AZURE_ENABLED = False


def _get_base_dir() -> Path:
    """Get the project base directory."""
    return Path(__file__).resolve().parents[1]


def _load_jsonl_to_cache(file_path: Path, series_key: str, cache_type: str) -> int:
    """Load a JSONL file into the cache.

    Args:
        file_path: Path to the JSONL file
        series_key: Key for time series data (e.g., "Time Series (Daily)")
        cache_type: Cache type ("daily" or "hourly")

    Returns:
        Number of symbols loaded
    """
    count = 0
    if not file_path.exists():
        logger.warning(f"Data file not found: {file_path}")
        return count

    with file_path.open("r", encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            try:
                doc = json.loads(line)
                meta = doc.get("Meta Data", {})
                symbol = meta.get("2. Symbol")
                if not symbol:
                    continue

                series = doc.get(series_key, {})
                if symbol not in _PRICE_CACHE:
                    _PRICE_CACHE[symbol] = {"daily": {}, "hourly": {}, "meta": meta}

                _PRICE_CACHE[symbol][cache_type].update(series)
                count += 1
            except json.JSONDecodeError as e:
                logger.warning(f"Failed to parse line in {file_path}: {e}")

    return count


def _ensure_cache_loaded() -> None:
    """Ensure the price cache is loaded. Thread-safe, loads only once."""
    global _CACHE_LOADED

    if _CACHE_LOADED:
        return

    with _CACHE_LOCK:
        if _CACHE_LOADED:
            return

        base_dir = _get_base_dir()
        total_symbols = 0

        logger.info("Loading price data into memory cache...")

        # Load US stocks daily data
        us_daily = base_dir / "data" / "merged.jsonl"
        count = _load_jsonl_to_cache(us_daily, "Time Series (Daily)", "daily")
        logger.info(f"  Loaded {count} US stock symbols (daily)")
        total_symbols += count

        # Load US stocks hourly data (if exists)
        us_hourly = base_dir / "data" / "merged_hourly.jsonl"
        if us_hourly.exists():
            count = _load_jsonl_to_cache(us_hourly, "Time Series (60min)", "hourly")
            logger.info(f"  Loaded {count} US stock symbols (hourly)")

        # Load A-shares daily data
        astock_daily = base_dir / "data" / "A_stock" / "merged.jsonl"
        count = _load_jsonl_to_cache(astock_daily, "Time Series (Daily)", "daily")
        logger.info(f"  Loaded {count} A-share symbols (daily)")
        total_symbols += count

        # Load A-shares hourly data
        astock_hourly = base_dir / "data" / "A_stock" / "merged_hourly.jsonl"
        if astock_hourly.exists():
            count = _load_jsonl_to_cache(astock_hourly, "Time Series (60min)", "hourly")
            logger.info(f"  Loaded {count} A-share symbols (hourly)")

        # Load crypto data
        crypto_daily = base_dir / "data" / "crypto" / "crypto_merged.jsonl"
        count = _load_jsonl_to_cache(crypto_daily, "Time Series (Daily)", "daily")
        logger.info(f"  Loaded {count} crypto symbols (daily)")
        total_symbols += count

        _CACHE_LOADED = True
        logger.info(f"Cache loaded: {total_symbols} total symbols, {len(_PRICE_CACHE)} unique symbols")


# =============================================================================
# Azure Table Storage Integration
# =============================================================================

def _init_azure_table_client():
    """Initialize Azure Table Storage client if configured."""
    global _TABLE_CLIENT, _AZURE_ENABLED

    connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
    table_name = os.getenv("AZURE_PRICE_TABLE_NAME", "pricedata")

    if not connection_string:
        logger.info("Azure Table Storage not configured (AZURE_STORAGE_CONNECTION_STRING not set)")
        return

    try:
        from azure.data.tables import TableClient
        _TABLE_CLIENT = TableClient.from_connection_string(connection_string, table_name)
        _AZURE_ENABLED = True
        logger.info(f"Azure Table Storage enabled: {table_name}")
    except ImportError:
        logger.warning("azure-data-tables package not installed, Azure Table Storage disabled")
    except Exception as e:
        logger.warning(f"Failed to initialize Azure Table Storage: {e}")


def _get_from_azure_table(symbol: str, date: str, data_type: str = "daily") -> Optional[Dict[str, Any]]:
    """Fetch price data from Azure Table Storage.

    Args:
        symbol: Stock symbol (used as PartitionKey)
        date: Date string (used as RowKey)
        data_type: "daily" or "hourly"

    Returns:
        OHLCV data dict or None if not found
    """
    if not _AZURE_ENABLED or not _TABLE_CLIENT:
        return None

    try:
        # PartitionKey = symbol, RowKey = date (with type prefix for hourly)
        row_key = f"{data_type}_{date}" if data_type == "hourly" else date
        entity = _TABLE_CLIENT.get_entity(partition_key=symbol, row_key=row_key)

        return {
            "1. buy price": entity.get("open"),
            "2. high": entity.get("high"),
            "3. low": entity.get("low"),
            "4. sell price": entity.get("close"),
            "5. volume": entity.get("volume"),
        }
    except Exception:
        return None


def _save_to_azure_table(symbol: str, date: str, ohlcv: Dict[str, Any], data_type: str = "daily") -> bool:
    """Save price data to Azure Table Storage.

    Args:
        symbol: Stock symbol (used as PartitionKey)
        date: Date string (used as RowKey)
        ohlcv: OHLCV data dictionary
        data_type: "daily" or "hourly"

    Returns:
        True if successful, False otherwise
    """
    if not _AZURE_ENABLED or not _TABLE_CLIENT:
        return False

    try:
        row_key = f"{data_type}_{date}" if data_type == "hourly" else date
        entity = {
            "PartitionKey": symbol,
            "RowKey": row_key,
            "open": ohlcv.get("1. buy price"),
            "high": ohlcv.get("2. high"),
            "low": ohlcv.get("3. low"),
            "close": ohlcv.get("4. sell price"),
            "volume": ohlcv.get("5. volume"),
            "dataType": data_type,
            "timestamp": datetime.utcnow().isoformat(),
        }
        _TABLE_CLIENT.upsert_entity(entity)
        return True
    except Exception as e:
        logger.warning(f"Failed to save to Azure Table Storage: {e}")
        return False


# =============================================================================
# Price Lookup Functions (Using Cache)
# =============================================================================

def _validate_date_daily(date_str: str) -> None:
    try:
        datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError as exc:
        raise ValueError("date must be in YYYY-MM-DD format") from exc


def _validate_date_hourly(date_str: str) -> None:
    try:
        datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")
    except ValueError as exc:
        raise ValueError("date must be in YYYY-MM-DD HH:MM:SS format") from exc


def _format_ohlcv_response(symbol: str, date: str, day_data: Dict[str, Any], is_today: bool) -> Dict[str, Any]:
    """Format OHLCV data for response, handling today's date restrictions."""
    if is_today:
        return {
            "symbol": symbol,
            "date": date,
            "ohlcv": {
                "open": day_data.get("1. buy price"),
                "high": "You can not get the current high price",
                "low": "You can not get the current low price",
                "close": "You can not get the next close price",
                "volume": "You can not get the current volume",
            },
        }
    else:
        return {
            "symbol": symbol,
            "date": date,
            "ohlcv": {
                "open": day_data.get("1. buy price"),
                "high": day_data.get("2. high"),
                "low": day_data.get("3. low"),
                "close": day_data.get("4. sell price"),
                "volume": day_data.get("5. volume"),
            },
        }


@mcp.tool()
def get_price_local(symbol: str, date: str) -> Dict[str, Any]:
    """Read OHLCV data for specified stock and date. Get historical information for specified stock.

    Automatically detects date format and calls appropriate function:
    - Daily data: YYYY-MM-DD format (e.g., '2025-10-30')
    - Hourly data: YYYY-MM-DD HH:MM:SS format (e.g., '2025-10-30 14:30:00')

    Args:
        symbol: Stock symbol, e.g. 'IBM' or '600243.SH'.
        date: Date in 'YYYY-MM-DD' or 'YYYY-MM-DD HH:MM:SS' format. Based on your current time format.

    Returns:
        Dictionary containing symbol, date and ohlcv data.
    """
    # Ensure cache is loaded
    _ensure_cache_loaded()

    # Detect date format
    if ' ' in date or 'T' in date:
        return get_price_local_hourly(symbol, date)
    else:
        return get_price_local_daily(symbol, date)


def get_price_local_daily(symbol: str, date: str) -> Dict[str, Any]:
    """Read daily OHLCV data for specified stock and date using cache.

    Args:
        symbol: Stock symbol, e.g. 'IBM' or '600243.SH'.
        date: Date in 'YYYY-MM-DD' format.

    Returns:
        Dictionary containing symbol, date and ohlcv data.
    """
    try:
        _validate_date_daily(date)
    except ValueError as e:
        return {"error": str(e), "symbol": symbol, "date": date}

    # Ensure cache is loaded
    _ensure_cache_loaded()

    # O(1) lookup from cache
    symbol_data = _PRICE_CACHE.get(symbol)

    if symbol_data:
        day_data = symbol_data.get("daily", {}).get(date)
        if day_data:
            is_today = date == get_config_value("TODAY_DATE")
            return _format_ohlcv_response(symbol, date, day_data, is_today)

        # Date not found in cache, return available dates
        available_dates = sorted(symbol_data.get("daily", {}).keys(), reverse=True)[:5]
        if available_dates:
            return {
                "error": f"Data not found for date {date}. Sample available dates: {available_dates}",
                "symbol": symbol,
                "date": date,
            }

    # Try Azure Table Storage fallback
    if _AZURE_ENABLED:
        azure_data = _get_from_azure_table(symbol, date, "daily")
        if azure_data:
            is_today = date == get_config_value("TODAY_DATE")
            return _format_ohlcv_response(symbol, date, azure_data, is_today)

    return {"error": f"No records found for stock {symbol} in local data", "symbol": symbol, "date": date}


def get_price_local_hourly(symbol: str, date: str) -> Dict[str, Any]:
    """Read hourly OHLCV data for specified stock and datetime using cache.

    Args:
        symbol: Stock symbol, e.g. 'IBM' or '600243.SH'.
        date: Datetime in 'YYYY-MM-DD HH:MM:SS' format.

    Returns:
        Dictionary containing symbol, date and ohlcv data.
    """
    try:
        _validate_date_hourly(date)
    except ValueError as e:
        return {"error": str(e), "symbol": symbol, "date": date}

    # Ensure cache is loaded
    _ensure_cache_loaded()

    # O(1) lookup from cache
    symbol_data = _PRICE_CACHE.get(symbol)

    if symbol_data:
        hour_data = symbol_data.get("hourly", {}).get(date)
        if hour_data:
            is_today = date == get_config_value("TODAY_DATE")
            return _format_ohlcv_response(symbol, date, hour_data, is_today)

        # Date not found in cache, return available dates
        available_dates = sorted(symbol_data.get("hourly", {}).keys(), reverse=True)[:5]
        if available_dates:
            return {
                "error": f"Data not found for date {date}. Sample available dates: {available_dates}",
                "symbol": symbol,
                "date": date,
            }

    # Try Azure Table Storage fallback
    if _AZURE_ENABLED:
        azure_data = _get_from_azure_table(symbol, date, "hourly")
        if azure_data:
            is_today = date == get_config_value("TODAY_DATE")
            return _format_ohlcv_response(symbol, date, azure_data, is_today)

    return {"error": f"No records found for stock {symbol} in local data", "symbol": symbol, "date": date}


# Legacy function for backwards compatibility
def get_price_local_function(symbol: str, date: str, filename: str = "merged.jsonl") -> Dict[str, Any]:
    """Read OHLCV data for specified stock and date from local JSONL data.

    Deprecated: Use get_price_local() instead for better performance.
    """
    return get_price_local_daily(symbol, date)


# =============================================================================
# Cache Statistics and Management
# =============================================================================

@mcp.tool()
def get_cache_stats() -> Dict[str, Any]:
    """Get statistics about the price data cache.

    Returns:
        Dictionary with cache statistics.
    """
    _ensure_cache_loaded()

    total_daily_entries = sum(len(data.get("daily", {})) for data in _PRICE_CACHE.values())
    total_hourly_entries = sum(len(data.get("hourly", {})) for data in _PRICE_CACHE.values())

    return {
        "cache_loaded": _CACHE_LOADED,
        "total_symbols": len(_PRICE_CACHE),
        "total_daily_entries": total_daily_entries,
        "total_hourly_entries": total_hourly_entries,
        "azure_enabled": _AZURE_ENABLED,
        "symbols": list(_PRICE_CACHE.keys())[:20],  # First 20 symbols
    }


def refresh_cache() -> Dict[str, Any]:
    """Force refresh the cache from disk.

    Returns:
        Dictionary with refresh status.
    """
    global _CACHE_LOADED, _PRICE_CACHE

    with _CACHE_LOCK:
        _PRICE_CACHE.clear()
        _CACHE_LOADED = False

    _ensure_cache_loaded()

    return get_cache_stats()


if __name__ == "__main__":
    # Initialize Azure Table Storage (if configured)
    _init_azure_table_client()

    # Pre-load cache on startup
    _ensure_cache_loaded()

    port = int(os.getenv("GETPRICE_HTTP_PORT", "8003"))
    mcp.run(transport="streamable-http", port=port)
