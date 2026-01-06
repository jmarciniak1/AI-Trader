# AI-Trader Azure Infrastructure

This directory contains the complete Infrastructure-as-Code (IaC) solution for deploying AI-Trader on Azure using Bicep templates.

## 🚀 Quick Start

```powershell
# 1. Run the complete deployment script
./scripts/Deploy.ps1 `
  -SubscriptionId "<your-subscription-id>" `
  -TenantId "<your-tenant-id>" `
  -ResourceGroupName "rg-aitrader-dev" `
  -Environment "dev"
```

## 📁 Directory Structure

```
infra/
├── main.bicep                      # Main orchestration template
├── bicepconfig.json                # Bicep linter configuration
├── README.md                       # This file
├── modules/                        # Reusable Bicep modules
│   ├── identity.bicep              # Managed Identity
│   ├── keyvault.bicep              # Azure Key Vault
│   ├── storage.bicep               # Storage Account
│   ├── acr.bicep                   # Container Registry
│   ├── monitoring.bicep            # Log Analytics & App Insights
│   ├── containerAppsEnv.bicep      # Container Apps Environment
│   ├── containerApps.bicep         # All Container Apps (7 services)
│   ├── aiFoundry.bicep             # AI Hub, Project, OpenAI
│   └── roleAssignments.bicep       # RBAC role assignments
├── parameters/                     # Environment-specific parameters
│   ├── dev.bicepparam              # Development parameters
│   ├── staging.bicepparam          # Staging parameters
│   └── prod.bicepparam             # Production parameters
├── scripts/                        # Deployment automation scripts
│   ├── Setup-AppRegistrations.ps1  # Create Azure AD app registrations
│   ├── Deploy.ps1                  # Full deployment orchestration
│   └── Cleanup.ps1                 # Cleanup failed deployments
└── docs/                           # Documentation
    └── DEPLOYMENT.md               # Comprehensive deployment guide
```

## 🏗️ Architecture Overview

### Core Resources
- **Managed Identity**: For secure service-to-service authentication
- **Key Vault**: Stores all API keys and secrets (RBAC-based)
- **Storage Account**: Blob containers for price-data, agent-data, logs
- **Container Registry**: Hosts Docker images for all services

### Compute Resources
- **Container Apps Environment**: Zone-redundant, consumption-based
- **Container Apps** (7 services):
  - `ca-math-service` (port 8000, internal)
  - `ca-search-service` (port 8001, internal)
  - `ca-trade-service` (port 8002, internal)
  - `ca-price-service` (port 8003, internal)
  - `ca-crypto-service` (port 8005, internal)
  - `ca-trading-agent` (main app, external)
  - `ca-web-ui` (port 8888, external)

### AI Resources
- **Azure AI Foundry Hub**: Central AI management
- **Azure AI Foundry Project**: Agent orchestration
- **Azure OpenAI Service**: GPT-4o and GPT-4-turbo deployments

### Monitoring
- **Log Analytics Workspace**: Centralized logging
- **Application Insights**: Application performance monitoring

### RBAC Roles
- Managed Identity → Key Vault Secrets User
- Managed Identity → Storage Blob Data Contributor
- Managed Identity → AcrPull
- Managed Identity → Cognitive Services OpenAI User
- Managed Identity → AzureML Data Scientist

## 🔧 Prerequisites

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed prerequisites including:
- Azure CLI 2.50.0+
- PowerShell 7+
- Microsoft.Graph PowerShell modules
- Docker (for building images)
- Required Azure roles and permissions

## 📝 Deployment Steps

### Option 1: Automated Deployment (Recommended)

```powershell
# Single command deployment
./scripts/Deploy.ps1 `
  -SubscriptionId "<subscription-id>" `
  -TenantId "<tenant-id>" `
  -ResourceGroupName "rg-aitrader-dev" `
  -Environment "dev"
```

### Option 2: Manual Step-by-Step Deployment

```bash
# 1. Create resource group
az group create --name rg-aitrader-dev --location eastus

# 2. Run app registration script (PowerShell)
./scripts/Setup-AppRegistrations.ps1 \
  -TenantId "<tenant-id>" \
  -SubscriptionId "<subscription-id>" \
  -Environment "dev"

# 3. Deploy Bicep template
az deployment group create \
  --name "aitrader-deployment" \
  --resource-group rg-aitrader-dev \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters tenantId="<tenant-id>"
```

## ✅ Validation

```bash
# Validate Bicep templates
az bicep build --file main.bicep

# Validate all modules
cd modules
for file in *.bicep; do
  az bicep build --file "$file"
done
```

## 🔐 Security Features

- ✅ All secrets stored in Azure Key Vault
- ✅ Managed Identity for service authentication
- ✅ RBAC-based access control
- ✅ Internal-only MCP services
- ✅ HTTPS enforced for external endpoints
- ✅ Soft delete enabled for Key Vault
- ✅ TLS 1.2+ required

## 💰 Cost Optimization

- Consumption-based Container Apps (scale to 0 possible, but we use minReplicas: 1)
- Basic tier for ACR (dev/staging)
- Standard tier for Key Vault
- Appropriate resource limits (CPU/memory)
- 30-day log retention for dev (90 days for prod)

**Estimated Monthly Cost:**
- Development: $120-620
- Production: $800-2450

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed cost breakdown.

## 🔄 Idempotency

All deployments are idempotent and safe to re-run:
- ✅ Bicep modules check for existing resources
- ✅ PowerShell scripts check for existing app registrations
- ✅ No duplicate resources created on re-run

## 🆘 Troubleshooting

Common issues and solutions:

### Bicep Validation Fails
```bash
az bicep build --file main.bicep
# Review error messages and fix syntax
```

### Insufficient Permissions
- Verify you have **Contributor** + **User Access Administrator** roles
- For app registrations: **Application Administrator** role required

### Container Apps Not Starting
```bash
az containerapp logs show \
  --name ca-math-service \
  --resource-group rg-aitrader-dev
```

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for comprehensive troubleshooting guide.

## 🧹 Cleanup

```powershell
# Remove all resources
./scripts/Cleanup.ps1 -ResourceGroupName "rg-aitrader-dev" -DeleteResourceGroup

# Or manually
az group delete --name rg-aitrader-dev --yes
```

## 📚 Documentation

- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)**: Comprehensive deployment guide with prerequisites, roles, troubleshooting
- **[Main Repository README](../README.md)**: Application documentation and usage

## 🤝 Contributing

When modifying infrastructure:
1. Update relevant Bicep modules
2. Validate with `az bicep build`
3. Test in dev environment first
4. Update documentation
5. Submit PR with clear description

## 📄 License

This infrastructure code is part of the AI-Trader project and follows the same MIT license. See [LICENSE](../LICENSE) for details.

## 🔗 Related Links

- [Azure Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [Azure OpenAI Documentation](https://docs.microsoft.com/azure/cognitive-services/openai/)
- [AI-Trader GitHub Repository](https://github.com/HKUDS/AI-Trader)
