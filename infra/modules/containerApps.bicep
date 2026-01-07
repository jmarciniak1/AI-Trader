// Container Apps Module
// Creates all Container Apps for AI-Trader services

@description('Location for Container Apps')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {}

@description('Resource ID of the Container Apps Environment')
param environmentId string

@description('Resource ID of the Managed Identity')
param managedIdentityId string

@description('ACR login server')
param acrLoginServer string

@description('Key Vault URI')
param keyVaultUri string

@description('Application Insights Connection String')
@secure()
param appInsightsConnectionString string

@description('Container image tag')
param imageTag string = 'latest'

// Math Service (Port 8000) - Internal
resource mathService 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-math-service'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 8000
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'math-service'
          image: '${acrLoginServer}/ai-trader/math-service:${imageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'MATH_HTTP_PORT'
              value: '8000'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            {
              name: 'KEY_VAULT_URI'
              value: keyVaultUri
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

// Search Service (Port 8001) - Internal
resource searchService 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-search-service'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 8001
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'search-service'
          image: '${acrLoginServer}/ai-trader/search-service:${imageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'SEARCH_HTTP_PORT'
              value: '8001'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            {
              name: 'KEY_VAULT_URI'
              value: keyVaultUri
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

// Trade Service (Port 8002) - Internal
resource tradeService 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-trade-service'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 8002
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'trade-service'
          image: '${acrLoginServer}/ai-trader/trade-service:${imageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'TRADE_HTTP_PORT'
              value: '8002'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            {
              name: 'KEY_VAULT_URI'
              value: keyVaultUri
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

// Price Service (Port 8003) - Internal
resource priceService 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-price-service'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 8003
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'price-service'
          image: '${acrLoginServer}/ai-trader/price-service:${imageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'GETPRICE_HTTP_PORT'
              value: '8003'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            {
              name: 'KEY_VAULT_URI'
              value: keyVaultUri
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

// Crypto Service (Port 8005) - Internal
resource cryptoService 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-crypto-service'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 8005
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'crypto-service'
          image: '${acrLoginServer}/ai-trader/crypto-service:${imageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'CRYPTO_HTTP_PORT'
              value: '8005'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            {
              name: 'KEY_VAULT_URI'
              value: keyVaultUri
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

// Trading Agent (Main App) - External
resource tradingAgent 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-trading-agent'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'trading-agent'
          image: '${acrLoginServer}/ai-trader/trading-agent:${imageTag}'
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          env: [
            {
              name: 'MATH_HTTP_PORT'
              value: '8000'
            }
            {
              name: 'SEARCH_HTTP_PORT'
              value: '8001'
            }
            {
              name: 'TRADE_HTTP_PORT'
              value: '8002'
            }
            {
              name: 'GETPRICE_HTTP_PORT'
              value: '8003'
            }
            {
              name: 'CRYPTO_HTTP_PORT'
              value: '8005'
            }
            {
              name: 'MATH_SERVICE_URL'
              value: 'http://${mathService.properties.configuration.ingress.fqdn}'
            }
            {
              name: 'SEARCH_SERVICE_URL'
              value: 'http://${searchService.properties.configuration.ingress.fqdn}'
            }
            {
              name: 'TRADE_SERVICE_URL'
              value: 'http://${tradeService.properties.configuration.ingress.fqdn}'
            }
            {
              name: 'PRICE_SERVICE_URL'
              value: 'http://${priceService.properties.configuration.ingress.fqdn}'
            }
            {
              name: 'CRYPTO_SERVICE_URL'
              value: 'http://${cryptoService.properties.configuration.ingress.fqdn}'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            {
              name: 'KEY_VAULT_URI'
              value: keyVaultUri
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 20
      }
    }
  }
}

// Web UI (Port 8888) - External
resource webUI 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-web-ui'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: true
        targetPort: 8888
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'web-ui'
          image: '${acrLoginServer}/ai-trader/web-ui:${imageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'PORT'
              value: '8888'
            }
            {
              name: 'TRADING_AGENT_URL'
              value: 'https://${tradingAgent.properties.configuration.ingress.fqdn}'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

@description('FQDN of the Trading Agent')
output tradingAgentFqdn string = tradingAgent.properties.configuration.ingress.fqdn

@description('FQDN of the Web UI')
output webUiFqdn string = webUI.properties.configuration.ingress.fqdn

@description('Internal FQDNs of MCP services')
output mcpServiceFqdns object = {
  math: mathService.properties.configuration.ingress.fqdn
  search: searchService.properties.configuration.ingress.fqdn
  trade: tradeService.properties.configuration.ingress.fqdn
  price: priceService.properties.configuration.ingress.fqdn
  crypto: cryptoService.properties.configuration.ingress.fqdn
}
