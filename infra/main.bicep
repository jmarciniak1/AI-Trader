// Main Bicep Template for AI-Trader Infrastructure
// Orchestrates deployment of all Azure resources with idempotency

targetScope = 'resourceGroup'

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string

@description('Tenant ID')
param tenantId string

@description('Base name for resources')
param baseName string = 'aitrader'

@description('Container image tag')
param imageTag string = 'latest'

@description('API keys and secrets (should be from Key Vault or parameter file)')
@secure()
param secrets object = {}

// Generate unique resource names
var resourceSuffix = '${environment}-${uniqueString(resourceGroup().id)}'
var identityName = '${baseName}-identity-${resourceSuffix}'
var keyVaultName = take('${baseName}-kv-${resourceSuffix}', 24)
var storageAccountName = take(replace('${baseName}st${resourceSuffix}', '-', ''), 24)
var acrName = take(replace('${baseName}acr${resourceSuffix}', '-', ''), 50)
var logAnalyticsName = '${baseName}-logs-${resourceSuffix}'
var appInsightsName = '${baseName}-insights-${resourceSuffix}'
var containerAppsEnvName = '${baseName}-env-${resourceSuffix}'
var aiHubName = '${baseName}-ai-hub-${resourceSuffix}'
var aiProjectName = '${baseName}-ai-project-${resourceSuffix}'
var openAIName = '${baseName}-openai-${resourceSuffix}'

// Tags
var tags = {
  Environment: environment
  Application: 'AI-Trader'
  ManagedBy: 'Bicep'
}

// Module 1: Managed Identity
module identity 'modules/identity.bicep' = {
  name: 'identity-deployment'
  params: {
    location: location
    identityName: identityName
    tags: tags
  }
}

// Module 2: Monitoring (Log Analytics & Application Insights)
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
    tags: tags
    retentionInDays: environment == 'prod' ? 90 : 30
  }
}

// Module 3: Key Vault
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    location: location
    keyVaultName: keyVaultName
    tenantId: tenantId
    tags: tags
    secrets: secrets
    enablePurgeProtection: environment == 'prod'
  }
}

// Module 4: Storage Account
module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    storageAccountName: storageAccountName
    tags: tags
    skuName: environment == 'prod' ? 'Standard_ZRS' : 'Standard_LRS'
    containerNames: [
      'price-data'
      'agent-data'
      'logs'
    ]
  }
}

// Module 5: Container Registry
module acr 'modules/acr.bicep' = {
  name: 'acr-deployment'
  params: {
    location: location
    acrName: acrName
    tags: tags
    skuName: environment == 'prod' ? 'Standard' : 'Basic'
  }
}

// Module 6: Azure OpenAI and AI Foundry
module aiFoundry 'modules/aiFoundry.bicep' = {
  name: 'ai-foundry-deployment'
  params: {
    location: location
    aiHubName: aiHubName
    aiProjectName: aiProjectName
    openAIName: openAIName
    storageAccountId: storage.outputs.storageAccountId
    keyVaultId: keyVault.outputs.keyVaultId
    appInsightsId: monitoring.outputs.appInsightsId
    managedIdentityId: identity.outputs.identityId
    tags: tags
    modelDeployments: [
      {
        name: 'gpt-4o'
        model: {
          format: 'OpenAI'
          name: 'gpt-4o'
          version: '2024-08-06'
        }
        sku: {
          name: 'Standard'
          capacity: environment == 'prod' ? 20 : 10
        }
      }
      {
        name: 'gpt-4-turbo'
        model: {
          format: 'OpenAI'
          name: 'gpt-4'
          version: 'turbo-2024-04-09'
        }
        sku: {
          name: 'Standard'
          capacity: environment == 'prod' ? 20 : 10
        }
      }
    ]
  }
}

// Module 7: Role Assignments
module roleAssignments 'modules/roleAssignments.bicep' = {
  name: 'role-assignments-deployment'
  params: {
    principalId: identity.outputs.principalId
    keyVaultId: keyVault.outputs.keyVaultId
    storageAccountId: storage.outputs.storageAccountId
    acrId: acr.outputs.acrId
    openAIId: aiFoundry.outputs.openAIId
    aiProjectId: aiFoundry.outputs.aiProjectId
  }
}

// Module 8: Container Apps Environment
module containerAppsEnv 'modules/containerAppsEnv.bicep' = {
  name: 'container-apps-env-deployment'
  params: {
    location: location
    environmentName: containerAppsEnvName
    tags: tags
    logAnalyticsCustomerId: monitoring.outputs.logAnalyticsCustomerId
    logAnalyticsSharedKey: monitoring.outputs.logAnalyticsSharedKey
    zoneRedundant: environment == 'prod'
  }
}

// Module 9: Container Apps (all services)
module containerApps 'modules/containerApps.bicep' = {
  name: 'container-apps-deployment'
  params: {
    location: location
    tags: tags
    environmentId: containerAppsEnv.outputs.environmentId
    managedIdentityId: identity.outputs.identityId
    acrLoginServer: acr.outputs.loginServer
    keyVaultUri: keyVault.outputs.keyVaultUri
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    imageTag: imageTag
  }
}

// Outputs
@description('Resource Group Name')
output resourceGroupName string = resourceGroup().name

@description('Managed Identity Details')
output identity object = {
  id: identity.outputs.identityId
  principalId: identity.outputs.principalId
  clientId: identity.outputs.clientId
  name: identity.outputs.identityName
}

@description('Key Vault Details')
output keyVault object = {
  id: keyVault.outputs.keyVaultId
  name: keyVault.outputs.keyVaultName
  uri: keyVault.outputs.keyVaultUri
}

@description('Storage Account Details')
output storage object = {
  id: storage.outputs.storageAccountId
  name: storage.outputs.storageAccountName
  endpoints: storage.outputs.primaryEndpoints
}

@description('Container Registry Details')
output containerRegistry object = {
  id: acr.outputs.acrId
  name: acr.outputs.acrName
  loginServer: acr.outputs.loginServer
}

@description('Monitoring Details')
output monitoring object = {
  logAnalyticsId: monitoring.outputs.logAnalyticsId
  logAnalyticsName: monitoring.outputs.logAnalyticsName
  appInsightsId: monitoring.outputs.appInsightsId
  appInsightsName: monitoring.outputs.appInsightsName
  appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
}

@description('AI Services Details')
output aiServices object = {
  aiHubId: aiFoundry.outputs.aiHubId
  aiHubName: aiFoundry.outputs.aiHubName
  aiProjectId: aiFoundry.outputs.aiProjectId
  aiProjectName: aiFoundry.outputs.aiProjectName
  openAIId: aiFoundry.outputs.openAIId
  openAIName: aiFoundry.outputs.openAIName
  openAIEndpoint: aiFoundry.outputs.openAIEndpoint
  deployedModels: aiFoundry.outputs.deployedModels
}

@description('Container Apps Endpoints')
output containerApps object = {
  tradingAgentUrl: 'https://${containerApps.outputs.tradingAgentFqdn}'
  webUiUrl: 'https://${containerApps.outputs.webUiFqdn}'
  mcpServiceFqdns: containerApps.outputs.mcpServiceFqdns
}

@description('Deployment Summary')
output deploymentSummary object = {
  environment: environment
  location: location
  resourcesDeployed: {
    identity: identity.outputs.identityName
    keyVault: keyVault.outputs.keyVaultName
    storage: storage.outputs.storageAccountName
    acr: acr.outputs.acrName
    aiHub: aiFoundry.outputs.aiHubName
    aiProject: aiFoundry.outputs.aiProjectName
    openAI: aiFoundry.outputs.openAIName
  }
}
