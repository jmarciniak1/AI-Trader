# Azure Infrastructure Deployment Guide for AI-Trader

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Minimum Required Roles](#minimum-required-roles)
- [Step-by-Step Deployment](#step-by-step-deployment)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Cost Estimation](#cost-estimation)
- [Security Best Practices](#security-best-practices)

## Overview

This infrastructure-as-code solution deploys a complete Azure environment for the AI-Trader application with:
- **Zero Cold Start**: All Container Apps have `minReplicas: 1`
- **High Availability**: Zone-redundant Container Apps Environment (prod)
- **Security**: Managed Identity with RBAC, all secrets in Key Vault
- **Cost Efficiency**: Consumption-based pricing with appropriate tiers
- **Idempotency**: Safe to re-run deployments without creating duplicates

### Architecture Components

| Component | Purpose | SKU/Tier |
|-----------|---------|----------|
| User-Assigned Managed Identity | Service authentication | N/A |
| Azure Key Vault | Secrets storage | Standard |
| Azure Storage Account | Data storage (JSONL files) | Standard_LRS/ZRS |
| Azure Container Registry | Docker images | Basic/Standard |
| Container Apps Environment | Hosting platform | Consumption |
| Container Apps (7 services) | Microservices | Consumption |
| Azure OpenAI Service | AI models (gpt-4o, gpt-4-turbo) | S0 |
| Azure AI Foundry Hub | AI management | N/A |
| Azure AI Foundry Project | Agent orchestration | N/A |
| Log Analytics Workspace | Logging | PerGB2018 |
| Application Insights | Monitoring | Workspace-based |

## Prerequisites

### Required Tools

1. **Azure CLI** (version 2.50.0 or later)
   ```bash
   # Install Azure CLI
   # Windows: https://aka.ms/installazurecli
   # macOS: brew install azure-cli
   # Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Verify installation
   az --version
   az bicep version
   ```

2. **PowerShell 7+** (for Windows, macOS, or Linux)
   ```bash
   # Install PowerShell 7
   # https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell
   
   # Verify installation
   pwsh --version
   ```

3. **PowerShell Modules**
   ```powershell
   # Install required modules
   Install-Module -Name Microsoft.Graph.Applications -Scope CurrentUser
   Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser
   
   # Verify installation
   Get-Module -ListAvailable Microsoft.Graph.*
   ```

4. **Docker** (for building container images)
   ```bash
   # Install Docker Desktop
   # https://docs.docker.com/get-docker/
   
   # Verify installation
   docker --version
   ```

### Required Information

Before deployment, gather the following:
- **Azure Tenant ID**: Found in Azure Portal > Azure Active Directory > Overview
- **Azure Subscription ID**: Found in Azure Portal > Subscriptions
- **Resource Group Name**: Choose a name (e.g., `rg-aitrader-dev`)
- **Azure Region**: Choose a region (e.g., `eastus`, `westus2`, `westeurope`)
- **Environment**: `dev`, `staging`, or `prod`

### API Keys (Store in Key Vault after deployment)
- **OPENAI_API_KEY**: OpenAI API key (or Azure OpenAI key)
- **ALPHAADVANTAGE_API_KEY**: Alpha Vantage API key for market data
- **JINA_API_KEY**: Jina AI API key for search
- **TUSHARE_TOKEN**: Tushare token for A-share data (optional)

## Minimum Required Roles

### For Bicep Deployment

The user running the Bicep deployment needs these **Azure RBAC** roles at the **Subscription** or **Resource Group** level:

| Role | Purpose | Scope |
|------|---------|-------|
| **Contributor** | Create and manage all Azure resources | Subscription or Resource Group |
| **User Access Administrator** | Assign RBAC roles to Managed Identity | Subscription or Resource Group |

**Alternative**: You can use **Owner** role which includes both permissions.

**To assign roles:**
```bash
# Assign Contributor role
az role assignment create \
  --assignee <user-principal-id> \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group-name>"

# Assign User Access Administrator role
az role assignment create \
  --assignee <user-principal-id> \
  --role "User Access Administrator" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group-name>"
```

### For App Registration Script

The user running the `Setup-AppRegistrations.ps1` script needs these **Entra ID (Azure AD)** roles:

| Role | Purpose | Required For |
|------|---------|--------------|
| **Application Administrator** | Create app registrations, grant consent | App registration creation |
| **Cloud Application Administrator** | Alternative to Application Administrator | App registration creation |

**Note**: **Global Administrator** role also has these permissions but is not recommended for least-privilege principle.

**To assign Entra ID roles:**
1. Navigate to Azure Portal > Azure Active Directory > Roles and administrators
2. Search for "Application Administrator"
3. Click the role and add the user as a member

**OR** use PowerShell:
```powershell
Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory"

$user = Get-MgUser -UserId "user@domain.com"
$role = Get-MgDirectoryRole -Filter "displayName eq 'Application Administrator'"

New-MgDirectoryRoleMemberByRef -DirectoryRoleId $role.Id -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)"
```

### For Granting Admin Consent

To grant admin consent for API permissions:

| Role | Scope |
|------|-------|
| **Application Administrator** | Can grant consent for all applications |
| **Cloud Application Administrator** | Can grant consent for all applications |
| **Global Administrator** | Can grant consent for all applications |

**Alternative**: If the user doesn't have these roles, they can navigate to the Azure Portal and click "Grant admin consent" button in the app registration's API permissions page (requires one of the above roles).

## Step-by-Step Deployment

### Step 1: Clone Repository and Navigate to Infrastructure

```bash
git clone https://github.com/HKUDS/AI-Trader.git
cd AI-Trader/infra
```

### Step 2: Authenticate with Azure

```bash
# Login to Azure CLI
az login --tenant <your-tenant-id>

# Set the subscription
az account set --subscription <your-subscription-id>

# Verify
az account show
```

### Step 3: Create Resource Group

```bash
# Set variables
RESOURCE_GROUP="rg-aitrader-dev"
LOCATION="eastus"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### Step 4: Update Parameter File

Edit the parameter file for your environment (e.g., `parameters/dev.bicepparam`):

```bicep
using './main.bicep'

param environment = 'dev'
param location = 'eastus'
param tenantId = '<your-tenant-id>'  // Fill in your tenant ID
param baseName = 'aitrader'
param imageTag = 'latest'

// Leave secrets empty - will be added to Key Vault manually after deployment
param secrets = {}
```

### Step 5: Run App Registration Script (PowerShell)

**Important**: This step requires **Application Administrator** role in Entra ID.

```powershell
# Navigate to scripts directory
cd scripts

# Run app registration script
./Setup-AppRegistrations.ps1 `
  -TenantId "<your-tenant-id>" `
  -SubscriptionId "<your-subscription-id>" `
  -Environment "dev"

# Review the output and save the app IDs and secrets
# The script will create a JSON file: app-registrations-dev.json
```

**Note**: Store the client secrets from the JSON file in a secure location (e.g., Azure Key Vault) and delete the JSON file.

### Step 6: Deploy Bicep Infrastructure

```bash
# Navigate back to infra directory
cd ..

# Validate the Bicep template
az bicep build --file main.bicep

# Deploy the infrastructure
az deployment group create \
  --name "aitrader-deployment-$(date +%Y%m%d%H%M%S)" \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters tenantId="<your-tenant-id>" \
  --verbose
```

**Estimated deployment time**: 10-15 minutes

**Alternative**: Use the `Deploy.ps1` script to automate steps 3-6:

```powershell
./scripts/Deploy.ps1 `
  -SubscriptionId "<your-subscription-id>" `
  -TenantId "<your-tenant-id>" `
  -ResourceGroupName "rg-aitrader-dev" `
  -Location "eastus" `
  -Environment "dev"
```

### Step 7: Grant Admin Consent (if not done in Step 5)

Navigate to each app registration in Azure Portal and grant admin consent:

1. Go to **Azure Portal** > **Azure Active Directory** > **App registrations**
2. Select each app (AI-Trader-API-dev, AI-Trader-Agents-dev, AI-Trader-MCP-dev)
3. Click **API permissions**
4. Click **Grant admin consent for [Your Organization]**
5. Confirm the consent

**OR** use the consent URLs from the app registration script output.

## Post-Deployment Configuration

### 1. Store API Keys in Key Vault

```bash
# Get Key Vault name from deployment output
KEY_VAULT_NAME=$(az deployment group show \
  --name <deployment-name> \
  --resource-group $RESOURCE_GROUP \
  --query properties.outputs.keyVault.value.name \
  --output tsv)

# Store secrets
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "OPENAI-API-KEY" --value "<your-openai-api-key>"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "ALPHAADVANTAGE-API-KEY" --value "<your-alphavantage-api-key>"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "JINA-API-KEY" --value "<your-jina-api-key>"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "TUSHARE-TOKEN" --value "<your-tushare-token>"

# Store app registration secrets
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "API-CLIENT-SECRET" --value "<api-app-secret>"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "AGENTS-CLIENT-SECRET" --value "<agents-app-secret>"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "MCP-CLIENT-SECRET" --value "<mcp-app-secret>"
```

### 2. Build and Push Docker Images

```bash
# Get ACR login server
ACR_NAME=$(az deployment group show \
  --name <deployment-name> \
  --resource-group $RESOURCE_GROUP \
  --query properties.outputs.containerRegistry.value.name \
  --output tsv)

ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)

# Login to ACR using Managed Identity (if running from Azure VM/Container)
# OR use admin credentials (for local development)
az acr login --name $ACR_NAME

# Build and push images (run from repository root)
cd ..

# Math Service
docker build -t $ACR_LOGIN_SERVER/ai-trader/math-service:latest -f Dockerfile.math .
docker push $ACR_LOGIN_SERVER/ai-trader/math-service:latest

# Search Service
docker build -t $ACR_LOGIN_SERVER/ai-trader/search-service:latest -f Dockerfile.search .
docker push $ACR_LOGIN_SERVER/ai-trader/search-service:latest

# Trade Service
docker build -t $ACR_LOGIN_SERVER/ai-trader/trade-service:latest -f Dockerfile.trade .
docker push $ACR_LOGIN_SERVER/ai-trader/trade-service:latest

# Price Service
docker build -t $ACR_LOGIN_SERVER/ai-trader/price-service:latest -f Dockerfile.price .
docker push $ACR_LOGIN_SERVER/ai-trader/price-service:latest

# Crypto Service
docker build -t $ACR_LOGIN_SERVER/ai-trader/crypto-service:latest -f Dockerfile.crypto .
docker push $ACR_LOGIN_SERVER/ai-trader/crypto-service:latest

# Trading Agent
docker build -t $ACR_LOGIN_SERVER/ai-trader/trading-agent:latest -f Dockerfile.agent .
docker push $ACR_LOGIN_SERVER/ai-trader/trading-agent:latest

# Web UI
docker build -t $ACR_LOGIN_SERVER/ai-trader/web-ui:latest -f Dockerfile.ui .
docker push $ACR_LOGIN_SERVER/ai-trader/web-ui:latest
```

**Note**: You'll need to create Dockerfiles for each service. See the "Creating Dockerfiles" section in the troubleshooting guide.

### 3. Update Container Apps with Images

After pushing images, Container Apps will automatically pull the latest images and restart.

Alternatively, force a revision update:

```bash
# Update a specific Container App
az containerapp update \
  --name ca-math-service \
  --resource-group $RESOURCE_GROUP \
  --image $ACR_LOGIN_SERVER/ai-trader/math-service:latest
```

## Verification

### 1. Check Resource Deployment

```bash
# List all resources in the resource group
az resource list --resource-group $RESOURCE_GROUP --output table

# Check Container Apps status
az containerapp list --resource-group $RESOURCE_GROUP --output table
```

### 2. Test Container Apps Endpoints

```bash
# Get Trading Agent URL
TRADING_AGENT_URL=$(az deployment group show \
  --name <deployment-name> \
  --resource-group $RESOURCE_GROUP \
  --query properties.outputs.containerApps.value.tradingAgentUrl \
  --output tsv)

# Get Web UI URL
WEB_UI_URL=$(az deployment group show \
  --name <deployment-name> \
  --resource-group $RESOURCE_GROUP \
  --query properties.outputs.containerApps.value.webUiUrl \
  --output tsv)

# Test endpoints
curl -f $TRADING_AGENT_URL/health || echo "Trading Agent not responding"
curl -f $WEB_UI_URL || echo "Web UI not responding"
```

### 3. Check Application Insights Logs

```bash
# Get Application Insights name
APP_INSIGHTS_NAME=$(az deployment group show \
  --name <deployment-name> \
  --resource-group $RESOURCE_GROUP \
  --query properties.outputs.monitoring.value.appInsightsName \
  --output tsv)

# Query logs (requires Azure CLI with Application Insights extension)
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --analytics-query "requests | take 10"
```

### 4. Verify Key Vault Access

```bash
# Test Managed Identity access to Key Vault
# (This should be done from within a Container App)

# List secrets (should work with Managed Identity)
az keyvault secret list --vault-name $KEY_VAULT_NAME
```

## Troubleshooting

### Common Errors

#### 1. **Bicep Validation Fails**

**Error**: `The template is not valid`

**Solution**:
```bash
# Check Bicep syntax
az bicep build --file main.bicep

# Review error messages and fix syntax issues
```

#### 2. **Insufficient Permissions for App Registration**

**Error**: `Insufficient privileges to complete the operation`

**Solution**:
- Verify you have **Application Administrator** role
- Ask your Global Administrator to grant you the role
- OR ask them to run the `Setup-AppRegistrations.ps1` script

#### 3. **Container Apps Not Starting**

**Error**: Container Apps show "Failed" or "Stopped" status

**Solution**:
```bash
# Check Container App logs
az containerapp logs show \
  --name ca-math-service \
  --resource-group $RESOURCE_GROUP \
  --type console

# Check revision status
az containerapp revision list \
  --name ca-math-service \
  --resource-group $RESOURCE_GROUP \
  --output table

# Common issues:
# - Docker image not found (check ACR)
# - Missing environment variables
# - Application crash on startup
```

#### 4. **ACR Pull Permission Denied**

**Error**: `Failed to pull image: unauthorized`

**Solution**:
```bash
# Check role assignment for Managed Identity
az role assignment list \
  --assignee <managed-identity-principal-id> \
  --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.ContainerRegistry/registries/<acr-name>

# Re-deploy role assignments if missing
az deployment group create \
  --name "role-fix-$(date +%Y%m%d%H%M%S)" \
  --resource-group $RESOURCE_GROUP \
  --template-file modules/roleAssignments.bicep \
  --parameters principalId=<managed-identity-principal-id> \
    keyVaultId=<key-vault-id> \
    storageAccountId=<storage-account-id> \
    acrId=<acr-id> \
    openAIId=<openai-id> \
    aiProjectId=<ai-project-id>
```

#### 5. **Key Vault Access Denied**

**Error**: `The user, group or application does not have secrets get permission`

**Solution**:
- Verify Managed Identity has "Key Vault Secrets User" role
- Check Key Vault network settings (should allow Azure Services)
- Verify RBAC authorization is enabled (not access policies)

#### 6. **OpenAI Deployment Fails**

**Error**: `Quota exceeded` or `Region not available`

**Solution**:
- Try a different region that supports Azure OpenAI
- Request quota increase in Azure Portal
- Use smaller model capacity (reduce from 20 to 10)

### Deployment Cleanup

If deployment fails and you need to start over:

```powershell
# Use the cleanup script
./scripts/Cleanup.ps1 -ResourceGroupName "rg-aitrader-dev"

# OR delete the entire resource group
az group delete --name "rg-aitrader-dev" --yes --no-wait
```

### Getting Help

- **Azure CLI Issues**: `az --help` or https://docs.microsoft.com/cli/azure/
- **Bicep Issues**: https://docs.microsoft.com/azure/azure-resource-manager/bicep/
- **Container Apps Issues**: https://docs.microsoft.com/azure/container-apps/
- **GitHub Issues**: https://github.com/HKUDS/AI-Trader/issues

## Cost Estimation

### Development Environment (dev)

| Resource | SKU/Tier | Estimated Monthly Cost (USD) |
|----------|----------|------------------------------|
| Container Apps (7x, 1 replica) | Consumption | $50-100 |
| Container Registry | Basic | $5 |
| Storage Account | Standard_LRS | $2-5 |
| Key Vault | Standard | $0.25 |
| Log Analytics | PerGB2018 (5GB) | $12 |
| Application Insights | Workspace-based | Included |
| Azure OpenAI | S0 (gpt-4o, gpt-4-turbo) | $50-500* |
| AI Foundry Hub/Project | N/A | $0 |
| **Total** | | **~$120-620/month** |

*OpenAI costs depend heavily on usage (tokens processed)

### Production Environment (prod)

| Resource | SKU/Tier | Estimated Monthly Cost (USD) |
|----------|----------|------------------------------|
| Container Apps (7x, 1-2 replicas, zone-redundant) | Consumption | $150-300 |
| Container Registry | Standard | $20 |
| Storage Account | Standard_ZRS | $5-10 |
| Key Vault | Standard | $0.25 |
| Log Analytics | PerGB2018 (50GB) | $120 |
| Application Insights | Workspace-based | Included |
| Azure OpenAI | S0 (gpt-4o, gpt-4-turbo, reserved) | $500-2000* |
| AI Foundry Hub/Project | N/A | $0 |
| **Total** | | **~$800-2450/month** |

*Consider reserved capacity for production OpenAI to reduce costs

### Cost Optimization Tips

1. **Use Consumption Tier**: Container Apps scale to zero when not in use (if you set minReplicas to 0, but this causes cold starts)
2. **Monitor Usage**: Set up Azure Cost Management alerts
3. **Right-Size Resources**: Adjust CPU/memory limits based on actual usage
4. **Use Reserved Instances**: For predictable OpenAI workloads
5. **Optimize Log Retention**: Reduce retention days for non-prod environments
6. **Delete Unused Environments**: Clean up dev/staging when not needed

## Security Best Practices

### 1. Secrets Management
- ✅ All secrets stored in Azure Key Vault
- ✅ No secrets in code or configuration files
- ✅ Managed Identity for accessing Key Vault
- ✅ Rotate secrets regularly

### 2. Network Security
- ✅ MCP services are internal-only (not exposed to internet)
- ✅ HTTPS enforced for external endpoints
- ✅ Azure Private Link (consider for production)

### 3. Identity and Access
- ✅ Managed Identity for all service-to-service communication
- ✅ RBAC-based Key Vault access (not access policies)
- ✅ Principle of least privilege for role assignments
- ✅ Multi-factor authentication for admin access

### 4. Monitoring and Auditing
- ✅ Application Insights for application logs
- ✅ Log Analytics for infrastructure logs
- ✅ Azure Monitor alerts for critical events
- ✅ Regular security audits

### 5. Data Protection
- ✅ Soft delete enabled for Key Vault (90 days retention)
- ✅ Purge protection enabled for production
- ✅ TLS 1.2 minimum for all services
- ✅ Private blob access (no public access)

### 6. Compliance
- Review Azure compliance offerings: https://docs.microsoft.com/azure/compliance/
- Enable Azure Policy for governance
- Implement Azure Security Center recommendations

## Additional Resources

- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [Azure Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure OpenAI Documentation](https://docs.microsoft.com/azure/cognitive-services/openai/)
- [Azure AI Foundry Documentation](https://docs.microsoft.com/azure/machine-learning/)
- [AI-Trader Repository](https://github.com/HKUDS/AI-Trader)

## Support

For issues related to:
- **Infrastructure deployment**: Create an issue in the AI-Trader repository
- **Azure resources**: Contact Azure Support
- **Application code**: See the main README.md in the repository root

---

**Note**: This infrastructure setup is designed for Azure deployment. For local development, refer to the main README.md in the repository root.
