// Azure Container Registry Module
// Creates ACR for storing Docker images

@description('Location for the container registry')
param location string = resourceGroup().location

@description('Name of the container registry')
param acrName string

@description('Tags to apply to resources')
param tags object = {}

@description('ACR SKU')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Basic'

@description('Enable admin user')
param adminUserEnabled bool = false

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: skuName == 'Premium' ? 'Enabled' : 'Disabled'
  }
}

@description('Resource ID of the container registry')
output acrId string = containerRegistry.id

@description('Name of the container registry')
output acrName string = containerRegistry.name

@description('Login server of the container registry')
output loginServer string = containerRegistry.properties.loginServer
