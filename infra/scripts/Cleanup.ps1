<#
.SYNOPSIS
    Cleanup script for failed AI-Trader deployments

.DESCRIPTION
    Safely removes resources from a failed deployment, with confirmation prompts

.PARAMETER ResourceGroupName
    Name of the resource group to clean up

.PARAMETER DeleteResourceGroup
    If specified, deletes the entire resource group (use with caution)

.PARAMETER DeleteAppRegistrations
    If specified, also deletes app registrations

.PARAMETER Environment
    Environment name (required if DeleteAppRegistrations is specified)

.EXAMPLE
    .\Cleanup.ps1 -ResourceGroupName "rg-aitrader-dev"

.EXAMPLE
    .\Cleanup.ps1 -ResourceGroupName "rg-aitrader-dev" -DeleteResourceGroup
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [switch]$DeleteResourceGroup,

    [Parameter(Mandatory = $false)]
    [switch]$DeleteAppRegistrations,

    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment
)

$ErrorActionPreference = 'Stop'

Write-Host "========================================" -ForegroundColor Red
Write-Host "AI-Trader Infrastructure Cleanup" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
if ($DeleteResourceGroup) {
    Write-Host "Action: DELETE ENTIRE RESOURCE GROUP" -ForegroundColor Red
}
else {
    Write-Host "Action: Delete individual failed resources" -ForegroundColor Yellow
}
Write-Host "========================================`n" -ForegroundColor Red

# Confirmation
$confirmation = Read-Host "Are you sure you want to proceed? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Cleanup cancelled" -ForegroundColor Green
    exit 0
}

# ============================================================
# Check if resource group exists
# ============================================================
Write-Host "`nChecking resource group..." -ForegroundColor Cyan

try {
    $rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
    
    if (-not $rgExists) {
        Write-Host "Resource group '$ResourceGroupName' does not exist" -ForegroundColor Yellow
        exit 0
    }
}
catch {
    Write-Error "Failed to check resource group: $_"
    exit 1
}

# ============================================================
# Delete Resource Group (if requested)
# ============================================================
if ($DeleteResourceGroup) {
    Write-Host "`nDeleting resource group (this may take several minutes)..." -ForegroundColor Red
    
    $finalConfirmation = Read-Host "This will DELETE ALL RESOURCES in '$ResourceGroupName'. Type the resource group name to confirm"
    if ($finalConfirmation -ne $ResourceGroupName) {
        Write-Host "Resource group name does not match. Cleanup cancelled" -ForegroundColor Green
        exit 0
    }
    
    try {
        az group delete --name $ResourceGroupName --yes --no-wait
        Write-Host "Resource group deletion initiated (running in background)" -ForegroundColor Yellow
        Write-Host "You can monitor progress in Azure Portal" -ForegroundColor Yellow
    }
    catch {
        Write-Error "Failed to delete resource group: $_"
        exit 1
    }
}
else {
    # ============================================================
    # List and optionally delete individual resources
    # ============================================================
    Write-Host "`nListing resources in resource group..." -ForegroundColor Cyan
    
    try {
        $resources = az resource list --resource-group $ResourceGroupName | ConvertFrom-Json
        
        if ($resources.Count -eq 0) {
            Write-Host "No resources found in resource group" -ForegroundColor Yellow
        }
        else {
            Write-Host "Found $($resources.Count) resources:" -ForegroundColor White
            foreach ($resource in $resources) {
                Write-Host "  - $($resource.name) ($($resource.type))" -ForegroundColor White
            }
            
            $deleteIndividual = Read-Host "`nDo you want to delete these resources individually? (yes/no)"
            if ($deleteIndividual -eq "yes") {
                foreach ($resource in $resources) {
                    Write-Host "`nDeleting: $($resource.name)" -ForegroundColor Yellow
                    try {
                        az resource delete --ids $resource.id --verbose
                        Write-Host "Deleted: $($resource.name)" -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "Failed to delete $($resource.name): $_"
                    }
                }
            }
        }
    }
    catch {
        Write-Error "Failed to list resources: $_"
        exit 1
    }
}

# ============================================================
# Delete App Registrations (if requested)
# ============================================================
if ($DeleteAppRegistrations) {
    if (-not $Environment) {
        Write-Error "Environment parameter is required when DeleteAppRegistrations is specified"
        exit 1
    }
    
    Write-Host "`nDeleting App Registrations..." -ForegroundColor Cyan
    
    # Import Microsoft.Graph module
    try {
        Import-Module Microsoft.Graph.Applications -ErrorAction Stop
        Connect-MgGraph -Scopes "Application.ReadWrite.All" -NoWelcome
    }
    catch {
        Write-Warning "Failed to connect to Microsoft Graph. Skipping app registration cleanup: $_"
        exit 0
    }
    
    $appNames = @(
        "AI-Trader-API-$Environment",
        "AI-Trader-Agents-$Environment",
        "AI-Trader-MCP-$Environment"
    )
    
    foreach ($appName in $appNames) {
        try {
            $apps = Get-MgApplication -Filter "displayName eq '$appName'"
            if ($apps.Count -gt 0) {
                $deleteApp = Read-Host "Delete app registration '$appName'? (yes/no)"
                if ($deleteApp -eq "yes") {
                    Remove-MgApplication -ApplicationId $apps[0].Id
                    Write-Host "Deleted app registration: $appName" -ForegroundColor Green
                }
            }
            else {
                Write-Host "App registration not found: $appName" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Warning "Failed to delete app registration '$appName': $_"
        }
    }
}

# ============================================================
# Cleanup Complete
# ============================================================
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Cleanup Complete" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

if ($DeleteResourceGroup) {
    Write-Host "Resource group deletion is running in the background" -ForegroundColor Yellow
    Write-Host "Monitor progress: Azure Portal > Resource Groups > $ResourceGroupName" -ForegroundColor Yellow
}
else {
    Write-Host "Individual resource cleanup completed" -ForegroundColor Green
    Write-Host "You may need to manually clean up remaining resources if any" -ForegroundColor Yellow
}

Write-Host "`nNote: Some resources may have soft-delete enabled (Key Vault, etc.)" -ForegroundColor Cyan
Write-Host "These will be permanently deleted after the retention period" -ForegroundColor Cyan
