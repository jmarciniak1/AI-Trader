# Example Dockerfiles for AI-Trader Services

This directory contains example Dockerfiles for containerizing the AI-Trader services for Azure Container Apps deployment.

## Base Python Image

All services use Python 3.10+ as the base image:

```dockerfile
FROM python:3.10-slim
```

## Service-Specific Dockerfiles

### 1. Math Service (Port 8000)

**File: `Dockerfile.math`**

```dockerfile
FROM python:3.10-slim

WORKDIR /app

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY agent_tools/tool_math.py ./agent_tools/
COPY agent_tools/__init__.py ./agent_tools/

# Set environment variables
ENV MATH_HTTP_PORT=8000
ENV PYTHONUNBUFFERED=1

# Expose port
EXPOSE 8000

# Run the service
CMD ["python", "-m", "agent_tools.tool_math"]
```

### 2. Search Service (Port 8001)

**File: `Dockerfile.search`**

```dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY agent_tools/tool_alphavantage_news.py ./agent_tools/
COPY agent_tools/__init__.py ./agent_tools/

ENV SEARCH_HTTP_PORT=8001
ENV PYTHONUNBUFFERED=1

EXPOSE 8001

CMD ["python", "-m", "agent_tools.tool_alphavantage_news"]
```

### 3. Trade Service (Port 8002)

**File: `Dockerfile.trade`**

```dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY agent_tools/tool_trade.py ./agent_tools/
COPY agent_tools/__init__.py ./agent_tools/

ENV TRADE_HTTP_PORT=8002
ENV PYTHONUNBUFFERED=1

EXPOSE 8002

CMD ["python", "-m", "agent_tools.tool_trade"]
```

### 4. Price Service (Port 8003)

**File: `Dockerfile.price`**

```dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY agent_tools/tool_get_price_local.py ./agent_tools/
COPY agent_tools/__init__.py ./agent_tools/
COPY data/ ./data/

ENV GETPRICE_HTTP_PORT=8003
ENV PYTHONUNBUFFERED=1

EXPOSE 8003

CMD ["python", "-m", "agent_tools.tool_get_price_local"]
```

### 5. Crypto Service (Port 8005)

**File: `Dockerfile.crypto`**

```dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY agent_tools/tool_crypto_trade.py ./agent_tools/
COPY agent_tools/__init__.py ./agent_tools/
COPY data/crypto/ ./data/crypto/

ENV CRYPTO_HTTP_PORT=8005
ENV PYTHONUNBUFFERED=1

EXPOSE 8005

CMD ["python", "-m", "agent_tools.tool_crypto_trade"]
```

### 6. Trading Agent (Main Application)

**File: `Dockerfile.agent`**

```dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all application code
COPY agent/ ./agent/
COPY agent_tools/ ./agent_tools/
COPY prompts/ ./prompts/
COPY configs/ ./configs/
COPY main.py .
COPY main_parrallel.py .

ENV PYTHONUNBUFFERED=1

EXPOSE 8080

# Run the main agent
CMD ["python", "main.py", "configs/default_config.json"]
```

### 7. Web UI (Port 8888)

**File: `Dockerfile.ui`**

```dockerfile
FROM python:3.10-slim

WORKDIR /app

# Install simple HTTP server
RUN pip install --no-cache-dir aiohttp

# Copy web UI files
COPY docs/ ./docs/

ENV PORT=8888
ENV PYTHONUNBUFFERED=1

EXPOSE 8888

# Serve the UI
CMD ["python", "-m", "http.server", "8888", "--directory", "docs"]
```

## Building Images

### Local Build

```bash
# Build all images locally
docker build -t ai-trader/math-service:latest -f Dockerfile.math .
docker build -t ai-trader/search-service:latest -f Dockerfile.search .
docker build -t ai-trader/trade-service:latest -f Dockerfile.trade .
docker build -t ai-trader/price-service:latest -f Dockerfile.price .
docker build -t ai-trader/crypto-service:latest -f Dockerfile.crypto .
docker build -t ai-trader/trading-agent:latest -f Dockerfile.agent .
docker build -t ai-trader/web-ui:latest -f Dockerfile.ui .
```

### Push to Azure Container Registry

```bash
# Login to ACR
az acr login --name <your-acr-name>

# Tag images
docker tag ai-trader/math-service:latest <acr-login-server>/ai-trader/math-service:latest
docker tag ai-trader/search-service:latest <acr-login-server>/ai-trader/search-service:latest
docker tag ai-trader/trade-service:latest <acr-login-server>/ai-trader/trade-service:latest
docker tag ai-trader/price-service:latest <acr-login-server>/ai-trader/price-service:latest
docker tag ai-trader/crypto-service:latest <acr-login-server>/ai-trader/crypto-service:latest
docker tag ai-trader/trading-agent:latest <acr-login-server>/ai-trader/trading-agent:latest
docker tag ai-trader/web-ui:latest <acr-login-server>/ai-trader/web-ui:latest

# Push images
docker push <acr-login-server>/ai-trader/math-service:latest
docker push <acr-login-server>/ai-trader/search-service:latest
docker push <acr-login-server>/ai-trader/trade-service:latest
docker push <acr-login-server>/ai-trader/price-service:latest
docker push <acr-login-server>/ai-trader/crypto-service:latest
docker push <acr-login-server>/ai-trader/trading-agent:latest
docker push <acr-login-server>/ai-trader/web-ui:latest
```

## Build Script

**File: `build-and-push.sh`**

```bash
#!/bin/bash
set -e

ACR_LOGIN_SERVER=${1:-"your-acr.azurecr.io"}
IMAGE_TAG=${2:-"latest"}

echo "Building and pushing to $ACR_LOGIN_SERVER with tag $IMAGE_TAG"

# Login to ACR
az acr login --name $(echo $ACR_LOGIN_SERVER | cut -d'.' -f1)

# Build and push each service
services=("math" "search" "trade" "price" "crypto" "agent" "ui")
ports=("8000" "8001" "8002" "8003" "8005" "8080" "8888")

for service in "${services[@]}"; do
    echo "Building $service-service..."
    docker build -t $ACR_LOGIN_SERVER/ai-trader/$service-service:$IMAGE_TAG -f Dockerfile.$service .
    
    echo "Pushing $service-service..."
    docker push $ACR_LOGIN_SERVER/ai-trader/$service-service:$IMAGE_TAG
done

echo "All images built and pushed successfully!"
```

Make the script executable:

```bash
chmod +x build-and-push.sh
```

Run the script:

```bash
./build-and-push.sh <your-acr-login-server> latest
```

## Multi-Architecture Builds (ARM64 + AMD64)

For production deployments, you may want to build multi-architecture images:

```bash
# Create a buildx builder
docker buildx create --name aitrader-builder --use

# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t $ACR_LOGIN_SERVER/ai-trader/math-service:latest \
  -f Dockerfile.math \
  --push .
```

## Environment Variables

Each service requires specific environment variables. These should be set in Container Apps configuration:

### All Services
- `PYTHONUNBUFFERED=1` - Enable Python output buffering

### Math Service
- `MATH_HTTP_PORT=8000`

### Search Service
- `SEARCH_HTTP_PORT=8001`
- `JINA_API_KEY` (from Key Vault)
- `ALPHAADVANTAGE_API_KEY` (from Key Vault)

### Trade Service
- `TRADE_HTTP_PORT=8002`

### Price Service
- `GETPRICE_HTTP_PORT=8003`
- `ALPHAADVANTAGE_API_KEY` (from Key Vault)

### Crypto Service
- `CRYPTO_HTTP_PORT=8005`
- `ALPHAADVANTAGE_API_KEY` (from Key Vault)

### Trading Agent
- `OPENAI_API_KEY` (from Key Vault)
- `OPENAI_API_BASE` (optional)
- `MATH_SERVICE_URL=http://ca-math-service.internal`
- `SEARCH_SERVICE_URL=http://ca-search-service.internal`
- `TRADE_SERVICE_URL=http://ca-trade-service.internal`
- `PRICE_SERVICE_URL=http://ca-price-service.internal`
- `CRYPTO_SERVICE_URL=http://ca-crypto-service.internal`

### Web UI
- `PORT=8888`
- `TRADING_AGENT_URL=https://ca-trading-agent.<fqdn>`

## Notes

1. **Adjust MCP Service Startup**: The example Dockerfiles assume each service can be run as a Python module. You may need to modify the startup commands based on how your MCP services are implemented.

2. **Data Files**: Services that need data files (price, crypto) should have those files copied into the container or mounted from Azure Storage.

3. **Health Checks**: Consider adding health check endpoints to each service for Container Apps health probes.

4. **Security**: Never include API keys or secrets in Docker images. Always use Azure Key Vault references in Container Apps.

5. **Optimization**: For production, consider:
   - Multi-stage builds to reduce image size
   - Distroless images for security
   - Layer caching optimization
   - Security scanning with `az acr scan`

## See Also

- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Azure Container Registry Documentation](https://docs.microsoft.com/azure/container-registry/)
