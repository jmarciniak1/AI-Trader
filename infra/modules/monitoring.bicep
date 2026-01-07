// Monitoring Module
// Creates Log Analytics Workspace and Application Insights

@description('Location for monitoring resources')
param location string = resourceGroup().location

@description('Name of the Log Analytics Workspace')
param logAnalyticsName string

@description('Name of Application Insights')
param appInsightsName string

@description('Tags to apply to resources')
param tags object = {}

@description('Log Analytics retention in days')
param retentionInDays int = 30

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('Resource ID of the Log Analytics Workspace')
output logAnalyticsId string = logAnalytics.id

@description('Name of the Log Analytics Workspace')
output logAnalyticsName string = logAnalytics.name

@description('Customer ID of the Log Analytics Workspace')
output logAnalyticsCustomerId string = logAnalytics.properties.customerId

@description('Primary Shared Key of the Log Analytics Workspace')
output logAnalyticsSharedKey string = logAnalytics.listKeys().primarySharedKey

@description('Resource ID of Application Insights')
output appInsightsId string = appInsights.id

@description('Name of Application Insights')
output appInsightsName string = appInsights.name

@description('Instrumentation Key of Application Insights')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('Connection String of Application Insights')
output appInsightsConnectionString string = appInsights.properties.ConnectionString
