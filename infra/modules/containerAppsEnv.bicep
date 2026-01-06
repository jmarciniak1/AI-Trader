// Container Apps Environment Module
// Creates Azure Container Apps Environment with zone redundancy

@description('Location for the Container Apps Environment')
param location string = resourceGroup().location

@description('Name of the Container Apps Environment')
param environmentName string

@description('Tags to apply to resources')
param tags object = {}

@description('Resource ID of the Log Analytics Workspace')
param logAnalyticsCustomerId string

@description('Shared Key of the Log Analytics Workspace')
@secure()
param logAnalyticsSharedKey string

@description('Enable zone redundancy')
param zoneRedundant bool = true

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsSharedKey
      }
    }
    zoneRedundant: zoneRedundant
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

@description('Resource ID of the Container Apps Environment')
output environmentId string = containerAppsEnvironment.id

@description('Name of the Container Apps Environment')
output environmentName string = containerAppsEnvironment.name

@description('Default domain of the Container Apps Environment')
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
