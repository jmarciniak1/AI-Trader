# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-Trader is an autonomous AI trading agent benchmarking platform. It enables multiple AI models (GPT, Claude, Qwen, etc.) to compete in simulated trading across NASDAQ 100, Chinese A-shares (SSE 50), and cryptocurrencies (BITWISE10). The system uses LangChain with MCP (Model Context Protocol) for tool-based execution.

## Common Commands

### Setup
```bash
pip install -r requirements.txt
cp .env.example .env  # Configure API keys
```

### Running the Trading System

**US Stocks (NASDAQ 100):**
```bash
# One-click (prepares data, starts MCP, runs agent)
bash scripts/main.sh

# Or step-by-step:
cd data && python get_daily_price.py && python merge_jsonl.py && cd ..
python agent_tools/start_mcp_services.py  # Keep running in separate terminal
python main.py configs/default_config.json
```

**A-Shares (SSE 50):**
```bash
cd data/A_stock && python get_daily_price_tushare.py && python merge_jsonl_tushare.py && cd ../..
python agent_tools/start_mcp_services.py
python main.py configs/astock_config.json
```

**Cryptocurrency:**
```bash
cd data/crypto && python get_daily_price_crypto.py && python merge_crypto_jsonl.py && cd ../..
python agent_tools/start_mcp_services.py
python main.py configs/default_crypto_config.json
```

### Calculate Performance Metrics
```bash
python tools/calculate_metrics.py --position-file data/agent_data/<model>/position/position.jsonl
```

## Architecture

### Agent Registry (main.py)
The system dynamically loads agent classes based on config:
- `BaseAgent` - US stocks daily trading
- `BaseAgent_Hour` - US stocks hourly trading
- `BaseAgentAStock` - A-shares daily (T+1 rules, 100-share lots)
- `BaseAgentAStock_Hour` - A-shares hourly (10:30/11:30/14:00/15:00)
- `BaseAgentCrypto` - Cryptocurrency (24/7, USDT denominated)

### MCP Tools (agent_tools/)
Services run on configurable ports (see .env):
- `tool_math.py` - Mathematical calculations (port 8000)
- `tool_alphavantage_news.py` - Market news search (port 8001)
- `tool_trade.py` - Stock buy/sell execution (port 8002)
- `tool_get_price_local.py` - Price queries (port 8003)
- `tool_crypto_trade.py` - Crypto trading (port 8005)

### Data Flow
1. Price data fetched via Alpha Vantage/Tushare APIs → stored as JSON
2. `merge_jsonl.py` converts to unified JSONL format
3. Agents read from `merged.jsonl` (or market-specific variants)
4. Trading records written to `data/agent_data/<signature>/position/position.jsonl`

### Configuration System
JSON configs in `configs/` define:
- `agent_type`: Which agent class to use
- `market`: "us", "cn", or "crypto"
- `date_range`: Backtest period (YYYY-MM-DD or with HH:MM:SS for hourly)
- `models`: List of AI models with `basemodel` and `signature`
- `agent_config`: max_steps, initial_cash, etc.
- `log_config`: Output path for trading logs

Environment variables in `.env` can override dates (`INIT_DATE`, `END_DATE`) and configure service ports.

### Anti-Look-Ahead Design
The system enforces temporal boundaries - agents only access price data up to the current simulation timestamp, preventing future information leakage.

## Key Files

- `main.py` - Entry point, loads config and runs agents
- `main_parrallel.py` - Parallel execution across multiple models
- `agent/base_agent/base_agent.py` - Core trading agent implementation
- `prompts/agent_prompt.py` - System prompts for US stock trading
- `prompts/agent_prompt_astock.py` - System prompts for A-share trading
- `tools/general_tools.py` - Runtime config management utilities
- `tools/calculate_metrics.py` - Performance metrics (CR, SR, Vol, MDD)

## Required API Keys

Configure in `.env`:
- `OPENAI_API_KEY` / `OPENAI_API_BASE` - For AI models
- `ALPHAADVANTAGE_API_KEY` - US stocks and crypto price data
- `JINA_API_KEY` - Market information search
- `TUSHARE_TOKEN` - A-share market data (optional)

## Azure Infrastructure (infra/)

The `infra/` directory contains Bicep IaC templates for deploying AI-Trader to Azure.

### Quick Deployment
```powershell
# Automated deployment
./infra/scripts/Deploy.ps1 `
  -SubscriptionId "<subscription-id>" `
  -TenantId "<tenant-id>" `
  -ResourceGroupName "rg-aitrader-dev" `
  -Environment "dev"

# Manual deployment
az group create --name rg-aitrader-dev --location eastus
az deployment group create --resource-group rg-aitrader-dev --template-file infra/main.bicep --parameters infra/parameters/dev.bicepparam
```

### Validate Bicep Templates
```bash
az bicep build --file infra/main.bicep
```

### Cleanup
```powershell
./infra/scripts/Cleanup.ps1 -ResourceGroupName "rg-aitrader-dev" -DeleteResourceGroup
```

### Azure Architecture
- **Container Apps** (7 services): Math (8000), Search (8001), Trade (8002), Price (8003), Crypto (8005), Trading Agent, Web UI (8888)
- **AI Foundry**: Hub, Project, and Azure OpenAI (GPT-4o, GPT-4-turbo)
- **Supporting**: Key Vault (secrets), Storage (price-data, agent-data, logs), ACR (container images), Log Analytics + App Insights

### Bicep Modules (infra/modules/)
- `identity.bicep` - Managed Identity
- `keyvault.bicep` - Key Vault with RBAC
- `storage.bicep` - Storage Account with blob containers
- `acr.bicep` - Container Registry
- `monitoring.bicep` - Log Analytics & App Insights
- `containerAppsEnv.bicep` - Container Apps Environment
- `containerApps.bicep` - All 7 Container Apps
- `aiFoundry.bicep` - AI Hub, Project, OpenAI
- `roleAssignments.bicep` - RBAC assignments

### Environment Parameters
- `infra/parameters/dev.bicepparam` - Development
- `infra/parameters/staging.bicepparam` - Staging
- `infra/parameters/prod.bicepparam` - Production
