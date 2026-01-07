// Azure Storage Account Module
// Creates storage account with blob containers and table storage for application data

@description('Location for the storage account')
param location string = resourceGroup().location

@description('Name of the storage account')
param storageAccountName string

@description('Tags to apply to resources')
param tags object = {}

@description('Storage account SKU')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param skuName string = 'Standard_LRS'

@description('Blob containers to create')
param containerNames array = [
  'price-data'
  'agent-data'
  'logs'
]

@description('Table names to create for structured data')
param tableNames array = [
  'pricedata'
  'agentpositions'
]

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for containerName in containerNames: {
  name: containerName
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}]

// Table Service for price data caching
resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
}

resource tables 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-01-01' = [for tableName in tableNames: {
  name: tableName
  parent: tableService
}]

@description('Resource ID of the storage account')
output storageAccountId string = storageAccount.id

@description('Name of the storage account')
output storageAccountName string = storageAccount.name

@description('Primary endpoints for the storage account')
output primaryEndpoints object = storageAccount.properties.primaryEndpoints

@description('Connection string for the storage account')
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

@description('Table endpoint URL')
output tableEndpoint string = storageAccount.properties.primaryEndpoints.table
