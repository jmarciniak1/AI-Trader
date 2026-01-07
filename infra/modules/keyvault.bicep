// Azure Key Vault Module
// Creates Key Vault with RBAC authorization and stores application secrets

@description('Location for the Key Vault')
param location string = resourceGroup().location

@description('Name of the Key Vault')
param keyVaultName string

@description('Tags to apply to resources')
param tags object = {}

@description('Tenant ID for the Key Vault')
param tenantId string

@description('Enable soft delete')
param enableSoftDelete bool = true

@description('Soft delete retention in days')
param softDeleteRetentionInDays int = 90

@description('Enable purge protection')
param enablePurgeProtection bool = true

@description('API keys and secrets to store')
@secure()
param secrets object = {}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableRbacAuthorization: true
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Store secrets if provided
resource secretResources 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = [for secret in items(secrets): if (!empty(secrets)) {
  name: secret.key
  parent: keyVault
  properties: {
    value: secret.value
    contentType: 'text/plain'
  }
}]

@description('Resource ID of the Key Vault')
output keyVaultId string = keyVault.id

@description('Name of the Key Vault')
output keyVaultName string = keyVault.name

@description('URI of the Key Vault')
output keyVaultUri string = keyVault.properties.vaultUri
