using './main.bicep'

param environment = 'prod'
param location = 'eastus'
param tenantId = '' // Fill in during deployment
param baseName = 'aitrader'
param imageTag = 'latest'

// Secrets should be provided via secure parameter file or Azure Key Vault reference
// Never commit actual secrets to source control
param secrets = {}
