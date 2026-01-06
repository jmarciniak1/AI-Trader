// Azure AI Foundry Module
// Creates AI Hub, AI Project, and Azure OpenAI Service

@description('Location for AI resources')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {}

@description('Name of the AI Hub')
param aiHubName string

@description('Name of the AI Project')
param aiProjectName string

@description('Name of the Azure OpenAI Service')
param openAIName string

@description('Resource ID of the Storage Account')
param storageAccountId string

@description('Resource ID of the Key Vault')
param keyVaultId string

@description('Resource ID of Application Insights')
param appInsightsId string

@description('Resource ID of the Log Analytics Workspace')
param logAnalyticsId string

@description('Resource ID of the Managed Identity')
param managedIdentityId string

@description('Principal ID of the Managed Identity')
param managedIdentityPrincipalId string

@description('OpenAI model deployments')
param modelDeployments array = [
  {
    name: 'gpt-4o'
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-08-06'
    }
    sku: {
      name: 'Standard'
      capacity: 10
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
      capacity: 10
    }
  }
]

// Azure OpenAI Service
resource openAI 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: openAIName
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    customSubDomainName: openAIName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// OpenAI Model Deployments
resource deployments 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = [for deployment in modelDeployments: {
  name: deployment.name
  parent: openAI
  sku: deployment.sku
  properties: {
    model: deployment.model
  }
}]

// AI Hub (Azure Machine Learning Workspace)
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: aiHubName
  location: location
  tags: tags
  kind: 'Hub'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    friendlyName: aiHubName
    description: 'AI Hub for AI-Trader application'
    storageAccount: storageAccountId
    keyVault: keyVaultId
    applicationInsights: appInsightsId
    primaryUserAssignedIdentity: managedIdentityId
    publicNetworkAccess: 'Enabled'
  }
}

// AI Project (Azure Machine Learning Workspace)
resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: aiProjectName
  location: location
  tags: tags
  kind: 'Project'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    friendlyName: aiProjectName
    description: 'AI Project for AI-Trader agent orchestration'
    hubResourceId: aiHub.id
    primaryUserAssignedIdentity: managedIdentityId
    publicNetworkAccess: 'Enabled'
  }
}

// Connected Azure OpenAI resource to AI Hub
resource aiServicesConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01' = {
  name: 'OpenAI-Connection'
  parent: aiHub
  properties: {
    category: 'AzureOpenAI'
    target: openAI.properties.endpoint
    authType: 'AAD'
    metadata: {
      ApiVersion: '2024-02-01'
      ResourceId: openAI.id
    }
  }
}

@description('Resource ID of the AI Hub')
output aiHubId string = aiHub.id

@description('Name of the AI Hub')
output aiHubName string = aiHub.name

@description('Resource ID of the AI Project')
output aiProjectId string = aiProject.id

@description('Name of the AI Project')
output aiProjectName string = aiProject.name

@description('Resource ID of Azure OpenAI Service')
output openAIId string = openAI.id

@description('Name of Azure OpenAI Service')
output openAIName string = openAI.name

@description('Endpoint of Azure OpenAI Service')
output openAIEndpoint string = openAI.properties.endpoint

@description('Deployed model names')
output deployedModels array = [for (deployment, i) in modelDeployments: deployments[i].name]
