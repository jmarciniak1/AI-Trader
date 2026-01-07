// User-Assigned Managed Identity Module
// Creates a managed identity for secure service-to-service authentication

@description('Location for the managed identity')
param location string = resourceGroup().location

@description('Name of the managed identity')
param identityName string

@description('Tags to apply to resources')
param tags object = {}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

@description('Resource ID of the managed identity')
output identityId string = managedIdentity.id

@description('Principal ID of the managed identity')
output principalId string = managedIdentity.properties.principalId

@description('Client ID of the managed identity')
output clientId string = managedIdentity.properties.clientId

@description('Name of the managed identity')
output identityName string = managedIdentity.name
