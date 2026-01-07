<#
.SYNOPSIS
    Complete deployment script for AI-Trader infrastructure

.DESCRIPTION
    Orchestrates the complete deployment of AI-Trader infrastructure including:
    1. Resource group creation
    2. App registrations
    3. Bicep deployment
    4. Post-deployment configuration

.PARAMETER SubscriptionId
    Azure Subscription ID

.PARAMETER TenantId
    Azure Tenant ID

.PARAMETER ResourceGroupName
    Name of the resource group to create/use

.PARAMETER Location
    Azure region for deployment (default: eastus)

.PARAMETER Environment
    Environment name (dev, staging, prod)

.PARAMETER SkipAppRegistrations
    Skip app registration setup (if already done)

.EXAMPLE
    .\Deploy.ps1 -SubscriptionId "xxx" -TenantId "yyy" -ResourceGroupName "rg-aitrader-dev" -Environment "dev"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAppRegistrations
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$infraDir = Split-Path -Parent $scriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AI-Trader Infrastructure Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Subscription: $SubscriptionId" -ForegroundColor White
Write-Host "Tenant: $TenantId" -ForegroundColor White
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "Location: $Location" -ForegroundColor White
Write-Host "Environment: $Environment" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

# ============================================================
# Step 1: Azure CLI Authentication
# ============================================================
Write-Host "Step 1: Authenticating with Azure..." -ForegroundColor Cyan

try {
    # Check if Azure CLI is installed
    $azVersion = az version 2>$null
    if (-not $azVersion) {
        throw "Azure CLI is not installed. Please install it from https://aka.ms/installazurecli"
    }
    
    # Login to Azure
    Write-Host "Logging in to Azure CLI..." -ForegroundColor Yellow
    az login --tenant $TenantId
    
    # Set subscription
    az account set --subscription $SubscriptionId
    
    $currentAccount = az account show | ConvertFrom-Json
    Write-Host "Logged in as: $($currentAccount.user.name)" -ForegroundColor Green
    Write-Host "Subscription: $($currentAccount.name)" -ForegroundColor Green
}
catch {
    Write-Error "Failed to authenticate with Azure: $_"
    exit 1
}

# ============================================================
# Step 2: Create Resource Group
# ============================================================
Write-Host "`nStep 2: Creating Resource Group..." -ForegroundColor Cyan

try {
    $rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
    
    if ($rgExists) {
        Write-Host "Resource group '$ResourceGroupName' already exists" -ForegroundColor Yellow
    }
    else {
        Write-Host "Creating resource group '$ResourceGroupName' in $Location..." -ForegroundColor Yellow
        az group create --name $ResourceGroupName --location $Location | Out-Null
        Write-Host "Resource group created successfully" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to create resource group: $_"
    exit 1
}

# ============================================================
# Step 3: Setup App Registrations
# ============================================================
if (-not $SkipAppRegistrations) {
    Write-Host "`nStep 3: Setting up App Registrations..." -ForegroundColor Cyan
    
    $appRegScript = Join-Path -Path $scriptDir -ChildPath "Setup-AppRegistrations.ps1"
    
    if (-not (Test-Path $appRegScript)) {
        Write-Error "App registration script not found: $appRegScript"
        exit 1
    }
    
    try {
        $appRegOutput = & $appRegScript -TenantId $TenantId -SubscriptionId $SubscriptionId -Environment $Environment
        Write-Host "App registrations completed successfully" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to setup app registrations: $_"
        Write-Warning "You may need to setup app registrations manually or re-run with appropriate permissions"
    }
}
else {
    Write-Host "`nStep 3: Skipping App Registrations (as requested)" -ForegroundColor Yellow
}

# ============================================================
# Step 4: Deploy Bicep Template
# ============================================================
Write-Host "`nStep 4: Deploying Bicep template..." -ForegroundColor Cyan

$bicepFile = Join-Path -Path $infraDir -ChildPath "main.bicep"
$parameterFile = Join-Path -Path $infraDir -ChildPath "parameters" | Join-Path -ChildPath "$Environment.bicepparam"

if (-not (Test-Path $bicepFile)) {
    Write-Error "Bicep template not found: $bicepFile"
    exit 1
}

if (-not (Test-Path $parameterFile)) {
    Write-Error "Parameter file not found: $parameterFile"
    exit 1
}

# Validate Bicep template
Write-Host "Validating Bicep template..." -ForegroundColor Yellow
try {
    az bicep build --file $bicepFile
    Write-Host "Bicep template validation successful" -ForegroundColor Green
}
catch {
    Write-Error "Bicep template validation failed: $_"
    exit 1
}

# Deploy Bicep template
Write-Host "Deploying infrastructure (this may take 10-15 minutes)..." -ForegroundColor Yellow

$deploymentName = "aitrader-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

try {
    $deployment = az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroupName `
        --template-file $bicepFile `
        --parameters $parameterFile `
        --parameters tenantId=$TenantId `
        --verbose | ConvertFrom-Json
    
    Write-Host "Infrastructure deployment completed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Infrastructure deployment failed: $_"
    Write-Host "`nTo troubleshoot, check the deployment in Azure Portal:" -ForegroundColor Yellow
    Write-Host "Resource Groups > $ResourceGroupName > Deployments > $deploymentName" -ForegroundColor Yellow
    exit 1
}

# ============================================================
# Step 5: Display Deployment Outputs
# ============================================================
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Deployment Summary:" -ForegroundColor Cyan
Write-Host "-------------------" -ForegroundColor Cyan

if ($deployment.properties.outputs) {
    $outputs = $deployment.properties.outputs
    
    if ($outputs.containerApps) {
        Write-Host "`nApplication Endpoints:" -ForegroundColor White
        Write-Host "  Trading Agent: $($outputs.containerApps.value.tradingAgentUrl)" -ForegroundColor White
        Write-Host "  Web UI: $($outputs.containerApps.value.webUiUrl)" -ForegroundColor White
    }
    
    if ($outputs.keyVault) {
        Write-Host "`nKey Vault:" -ForegroundColor White
        Write-Host "  Name: $($outputs.keyVault.value.name)" -ForegroundColor White
        Write-Host "  URI: $($outputs.keyVault.value.uri)" -ForegroundColor White
    }
    
    if ($outputs.containerRegistry) {
        Write-Host "`nContainer Registry:" -ForegroundColor White
        Write-Host "  Login Server: $($outputs.containerRegistry.value.loginServer)" -ForegroundColor White
    }
    
    if ($outputs.aiServices) {
        Write-Host "`nAI Services:" -ForegroundColor White
        Write-Host "  OpenAI Endpoint: $($outputs.aiServices.value.openAIEndpoint)" -ForegroundColor White
        Write-Host "  AI Hub: $($outputs.aiServices.value.aiHubName)" -ForegroundColor White
        Write-Host "  AI Project: $($outputs.aiServices.value.aiProjectName)" -ForegroundColor White
    }
}

# ============================================================
# Step 6: Post-Deployment Instructions
# ============================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "1. Store API keys in Key Vault:" -ForegroundColor Yellow
Write-Host "   - OPENAI_API_KEY" -ForegroundColor White
Write-Host "   - ALPHAADVANTAGE_API_KEY" -ForegroundColor White
Write-Host "   - JINA_API_KEY" -ForegroundColor White
Write-Host "   - TUSHARE_TOKEN" -ForegroundColor White

Write-Host "`n2. Build and push Docker images to ACR:" -ForegroundColor Yellow
Write-Host "   - Math Service (port 8000)" -ForegroundColor White
Write-Host "   - Search Service (port 8001)" -ForegroundColor White
Write-Host "   - Trade Service (port 8002)" -ForegroundColor White
Write-Host "   - Price Service (port 8003)" -ForegroundColor White
Write-Host "   - Crypto Service (port 8005)" -ForegroundColor White
Write-Host "   - Trading Agent (main app)" -ForegroundColor White
Write-Host "   - Web UI (port 8888)" -ForegroundColor White

Write-Host "`n3. Grant admin consent for app registrations (if not done):" -ForegroundColor Yellow
Write-Host "   Azure Portal > Azure Active Directory > App registrations" -ForegroundColor White

Write-Host "`n4. Verify deployment:" -ForegroundColor Yellow
Write-Host "   - Check Container Apps are running" -ForegroundColor White
Write-Host "   - Test application endpoints" -ForegroundColor White
Write-Host "   - Review Application Insights logs" -ForegroundColor White

Write-Host "`nFor detailed instructions, see: infra/docs/DEPLOYMENT.md" -ForegroundColor Cyan

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Deployment script completed successfully!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
