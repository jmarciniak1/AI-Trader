<#
.SYNOPSIS
    Setup Azure App Registrations for AI-Trader with idempotency

.DESCRIPTION
    Creates or updates three App Registrations:
    1. AI-Trader-API: Main application authentication
    2. AI-Trader-Agents: Azure AI Foundry agent service access
    3. AI-Trader-MCP: MCP service-to-service communication
    
    This script is idempotent - it safely checks for existing resources before creating.

.PARAMETER TenantId
    Azure Tenant ID

.PARAMETER SubscriptionId
    Azure Subscription ID

.PARAMETER Environment
    Environment name (dev, staging, prod)

.PARAMETER ContainerAppsFqdn
    FQDN of the Container Apps for redirect URIs (optional)

.EXAMPLE
    .\Setup-AppRegistrations.ps1 -TenantId "xxx" -SubscriptionId "yyy" -Environment "dev"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$ContainerAppsFqdn = ""
)

$ErrorActionPreference = 'Stop'

# Import required modules
Write-Host "Checking required PowerShell modules..." -ForegroundColor Cyan

$requiredModules = @('Microsoft.Graph.Applications', 'Microsoft.Graph.Authentication')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module $module -ErrorAction Stop
}

# Connect to Microsoft Graph
Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Cyan
try {
    Connect-MgGraph -TenantId $TenantId -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All" -NoWelcome
    Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    exit 1
}

# Helper function to check if app registration exists
function Get-AppRegistrationByName {
    param([string]$DisplayName)
    
    Write-Verbose "Checking if app registration '$DisplayName' exists..."
    $apps = Get-MgApplication -Filter "displayName eq '$DisplayName'"
    
    if ($apps.Count -gt 0) {
        Write-Host "Found existing app registration: $DisplayName" -ForegroundColor Yellow
        return $apps[0]
    }
    return $null
}

# Helper function to check if service principal exists
function Get-ServicePrincipalByAppId {
    param([string]$AppId)
    
    $sps = Get-MgServicePrincipal -Filter "appId eq '$AppId'"
    if ($sps.Count -gt 0) {
        return $sps[0]
    }
    return $null
}

# Helper function to create or get service principal
function Ensure-ServicePrincipal {
    param([string]$AppId)
    
    $sp = Get-ServicePrincipalByAppId -AppId $AppId
    if (-not $sp) {
        Write-Host "Creating service principal for app ID: $AppId" -ForegroundColor Cyan
        $sp = New-MgServicePrincipal -AppId $AppId
        Write-Host "Service principal created successfully" -ForegroundColor Green
    }
    else {
        Write-Host "Service principal already exists for app ID: $AppId" -ForegroundColor Yellow
    }
    return $sp
}

# Microsoft Graph API permissions
$graphApiId = "00000003-0000-0000-c000-000000000000"
$graphPermissions = @(
    @{
        Id = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"  # User.Read
        Type = "Scope"
    }
)

# Azure Service Management permissions
$azureServiceMgmtApiId = "797f4846-ba00-4fd7-ba43-dac1f8f63013"
$azureServiceMgmtPermissions = @(
    @{
        Id = "41094075-9dad-400e-a0bd-54e686782033"  # user_impersonation
        Type = "Scope"
    }
)

# Cognitive Services permissions
$cognitiveServicesApiId = "00000003-0000-0000-c000-000000000000"
$cognitiveServicesPermissions = @(
    @{
        Id = "d85c5617-e8dd-4739-8c2c-5ea6d5aaf176"  # OpenAI.ReadWrite (placeholder - use actual if available)
        Type = "Scope"
    }
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setting up App Registrations for: $Environment" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ============================================================
# 1. AI-Trader-API App Registration
# ============================================================
$apiAppName = "AI-Trader-API-$Environment"
Write-Host "Processing: $apiAppName" -ForegroundColor Cyan

$apiApp = Get-AppRegistrationByName -DisplayName $apiAppName

if (-not $apiApp) {
    Write-Host "Creating app registration: $apiAppName" -ForegroundColor Cyan
    
    $apiApp = New-MgApplication -DisplayName $apiAppName `
        -SignInAudience "AzureADMyOrg" `
        -Web @{
            RedirectUris = @(
                "http://localhost:8080/auth/callback"
                if ($ContainerAppsFqdn) { "https://$ContainerAppsFqdn/auth/callback" }
            )
            ImplicitGrantSettings = @{
                EnableIdTokenIssuance = $true
                EnableAccessTokenIssuance = $true
            }
        } `
        -Api @{
            Oauth2PermissionScopes = @(
                @{
                    Id = [Guid]::NewGuid().ToString()
                    AdminConsentDescription = "Allow the application to access AI-Trader API on behalf of the signed-in user"
                    AdminConsentDisplayName = "Access AI-Trader API"
                    IsEnabled = $true
                    Type = "User"
                    UserConsentDescription = "Allow the application to access AI-Trader API on your behalf"
                    UserConsentDisplayName = "Access AI-Trader API"
                    Value = "Trading.ReadWrite"
                }
            )
        } `
        -RequiredResourceAccess @(
            @{
                ResourceAppId = $graphApiId
                ResourceAccess = $graphPermissions
            },
            @{
                ResourceAppId = $azureServiceMgmtApiId
                ResourceAccess = $azureServiceMgmtPermissions
            }
        )
    
    Write-Host "App registration created: $apiAppName" -ForegroundColor Green
    Write-Host "  App ID: $($apiApp.AppId)" -ForegroundColor Green
}
else {
    Write-Host "App registration already exists: $apiAppName" -ForegroundColor Yellow
    Write-Host "  App ID: $($apiApp.AppId)" -ForegroundColor Yellow
}

# Create service principal for API app
$apiSp = Ensure-ServicePrincipal -AppId $apiApp.AppId

# Create client secret for API app
Write-Host "Creating client secret for: $apiAppName" -ForegroundColor Cyan
$apiSecretName = "Secret-$Environment-$(Get-Date -Format 'yyyyMMdd')"
$apiPasswordCredential = Add-MgApplicationPassword -ApplicationId $apiApp.Id -PasswordCredential @{
    DisplayName = $apiSecretName
    EndDateTime = (Get-Date).AddYears(1)
}
Write-Host "Client secret created (expires in 1 year)" -ForegroundColor Green

# ============================================================
# 2. AI-Trader-Agents App Registration
# ============================================================
$agentsAppName = "AI-Trader-Agents-$Environment"
Write-Host "`nProcessing: $agentsAppName" -ForegroundColor Cyan

$agentsApp = Get-AppRegistrationByName -DisplayName $agentsAppName

if (-not $agentsApp) {
    Write-Host "Creating app registration: $agentsAppName" -ForegroundColor Cyan
    
    $agentsApp = New-MgApplication -DisplayName $agentsAppName `
        -SignInAudience "AzureADMyOrg" `
        -RequiredResourceAccess @(
            @{
                ResourceAppId = $graphApiId
                ResourceAccess = $graphPermissions
            }
        )
    
    Write-Host "App registration created: $agentsAppName" -ForegroundColor Green
    Write-Host "  App ID: $($agentsApp.AppId)" -ForegroundColor Green
}
else {
    Write-Host "App registration already exists: $agentsAppName" -ForegroundColor Yellow
    Write-Host "  App ID: $($agentsApp.AppId)" -ForegroundColor Yellow
}

# Create service principal for Agents app
$agentsSp = Ensure-ServicePrincipal -AppId $agentsApp.AppId

# Create client secret for Agents app
Write-Host "Creating client secret for: $agentsAppName" -ForegroundColor Cyan
$agentsSecretName = "Secret-$Environment-$(Get-Date -Format 'yyyyMMdd')"
$agentsPasswordCredential = Add-MgApplicationPassword -ApplicationId $agentsApp.Id -PasswordCredential @{
    DisplayName = $agentsSecretName
    EndDateTime = (Get-Date).AddYears(1)
}
Write-Host "Client secret created (expires in 1 year)" -ForegroundColor Green

# ============================================================
# 3. AI-Trader-MCP App Registration
# ============================================================
$mcpAppName = "AI-Trader-MCP-$Environment"
Write-Host "`nProcessing: $mcpAppName" -ForegroundColor Cyan

$mcpApp = Get-AppRegistrationByName -DisplayName $mcpAppName

if (-not $mcpApp) {
    Write-Host "Creating app registration: $mcpAppName" -ForegroundColor Cyan
    
    $mcpApp = New-MgApplication -DisplayName $mcpAppName `
        -SignInAudience "AzureADMyOrg" `
        -RequiredResourceAccess @(
            @{
                ResourceAppId = $graphApiId
                ResourceAccess = $graphPermissions
            }
        )
    
    Write-Host "App registration created: $mcpAppName" -ForegroundColor Green
    Write-Host "  App ID: $($mcpApp.AppId)" -ForegroundColor Green
}
else {
    Write-Host "App registration already exists: $mcpAppName" -ForegroundColor Yellow
    Write-Host "  App ID: $($mcpApp.AppId)" -ForegroundColor Yellow
}

# Create service principal for MCP app
$mcpSp = Ensure-ServicePrincipal -AppId $mcpApp.AppId

# Create client secret for MCP app
Write-Host "Creating client secret for: $mcpAppName" -ForegroundColor Cyan
$mcpSecretName = "Secret-$Environment-$(Get-Date -Format 'yyyyMMdd')"
$mcpPasswordCredential = Add-MgApplicationPassword -ApplicationId $mcpApp.Id -PasswordCredential @{
    DisplayName = $mcpSecretName
    EndDateTime = (Get-Date).AddYears(1)
}
Write-Host "Client secret created (expires in 1 year)" -ForegroundColor Green

# ============================================================
# Admin Consent (Optional - requires Application Administrator role)
# ============================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Admin Consent" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "To grant admin consent, a user with Application Administrator or Global Administrator role must:" -ForegroundColor Yellow
Write-Host "1. Navigate to Azure Portal > Azure Active Directory > App registrations" -ForegroundColor Yellow
Write-Host "2. Select each app registration and go to 'API permissions'" -ForegroundColor Yellow
Write-Host "3. Click 'Grant admin consent for [Your Organization]'" -ForegroundColor Yellow
Write-Host "`nOr use the following URLs (requires admin permissions):`n" -ForegroundColor Yellow

$consentUrls = @(
    "https://login.microsoftonline.com/$TenantId/adminconsent?client_id=$($apiApp.AppId)"
    "https://login.microsoftonline.com/$TenantId/adminconsent?client_id=$($agentsApp.AppId)"
    "https://login.microsoftonline.com/$TenantId/adminconsent?client_id=$($mcpApp.AppId)"
)

foreach ($url in $consentUrls) {
    Write-Host "  $url" -ForegroundColor Cyan
}

# ============================================================
# Output Summary
# ============================================================
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "App Registrations Setup Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

$output = @{
    Environment = $Environment
    TenantId = $TenantId
    SubscriptionId = $SubscriptionId
    Applications = @{
        API = @{
            Name = $apiAppName
            AppId = $apiApp.AppId
            ClientSecret = $apiPasswordCredential.SecretText
            ObjectId = $apiApp.Id
            ServicePrincipalId = $apiSp.Id
        }
        Agents = @{
            Name = $agentsAppName
            AppId = $agentsApp.AppId
            ClientSecret = $agentsPasswordCredential.SecretText
            ObjectId = $agentsApp.Id
            ServicePrincipalId = $agentsSp.Id
        }
        MCP = @{
            Name = $mcpAppName
            AppId = $mcpApp.AppId
            ClientSecret = $mcpPasswordCredential.SecretText
            ObjectId = $mcpApp.Id
            ServicePrincipalId = $mcpSp.Id
        }
    }
}

# Display output
Write-Host "Application Details:" -ForegroundColor Cyan
Write-Host "-------------------" -ForegroundColor Cyan
Write-Host "`n1. $apiAppName" -ForegroundColor White
Write-Host "   App ID: $($apiApp.AppId)" -ForegroundColor White
Write-Host "   Object ID: $($apiApp.Id)" -ForegroundColor White
Write-Host "`n2. $agentsAppName" -ForegroundColor White
Write-Host "   App ID: $($agentsApp.AppId)" -ForegroundColor White
Write-Host "   Object ID: $($agentsApp.Id)" -ForegroundColor White
Write-Host "`n3. $mcpAppName" -ForegroundColor White
Write-Host "   App ID: $($mcpApp.AppId)" -ForegroundColor White
Write-Host "   Object ID: $($mcpApp.Id)" -ForegroundColor White

# Save output to JSON file
$outputPath = Join-Path -Path $PSScriptRoot -ChildPath "app-registrations-$Environment.json"
$output | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8
Write-Host "`nConfiguration saved to: $outputPath" -ForegroundColor Green

# WARNING about secrets
Write-Host "`n⚠️  IMPORTANT: Client secrets have been generated!" -ForegroundColor Red
Write-Host "These secrets are displayed only once and saved to the JSON file." -ForegroundColor Red
Write-Host "Store them securely in Azure Key Vault immediately!" -ForegroundColor Red
Write-Host "Delete the JSON file after storing the secrets securely." -ForegroundColor Red

return $output
