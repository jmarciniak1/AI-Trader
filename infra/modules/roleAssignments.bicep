// RBAC Role Assignments Module
// Assigns necessary roles to the managed identity for secure access

@description('Principal ID of the Managed Identity')
param principalId string

@description('Resource ID of the Key Vault')
param keyVaultId string

@description('Resource ID of the Storage Account')
param storageAccountId string

@description('Resource ID of the Container Registry')
param acrId string

@description('Resource ID of the Azure OpenAI Service')
param openAIId string

@description('Resource ID of the AI Project')
param aiProjectId string

// Built-in Azure RBAC Role Definition IDs
var roles = {
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  cognitiveServicesOpenAIUser: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  azureMLDataScientist: 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
}

// Key Vault Secrets User - for reading secrets from Key Vault
resource keyVaultSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultId, principalId, roles.keyVaultSecretsUser)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Contributor - for accessing blob storage
resource storageBlobDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, principalId, roles.storageBlobDataContributor)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// AcrPull - for pulling images from Container Registry
resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrId, principalId, roles.acrPull)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Cognitive Services OpenAI User - for using Azure OpenAI
resource cognitiveServicesOpenAIUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAIId, principalId, roles.cognitiveServicesOpenAIUser)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.cognitiveServicesOpenAIUser)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// AzureML Data Scientist - for AI Project access
resource azureMLDataScientistAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiProjectId, principalId, roles.azureMLDataScientist)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.azureMLDataScientist)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Role assignment IDs')
output roleAssignmentIds object = {
  keyVaultSecretsUser: keyVaultSecretsUserAssignment.id
  storageBlobDataContributor: storageBlobDataContributorAssignment.id
  acrPull: acrPullAssignment.id
  cognitiveServicesOpenAIUser: cognitiveServicesOpenAIUserAssignment.id
  azureMLDataScientist: azureMLDataScientistAssignment.id
}
