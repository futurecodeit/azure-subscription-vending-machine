@description('Logic App name')
param logicAppName string = 'sub-vending-logicapp'

@description('Location of the Logic App')
param location string = resourceGroup().location

@description('Terraform runner URL invoked by the workflow')
param terraformRunnerUrl string = 'https://example.com/terraform-runner'

@description('Storage account name for Logic App state')
param storageAccountName string = 'subvendinglogicapp${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${logicAppName}-plan'
  location: location
  kind: 'elastic'
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
  }
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        terraformRunnerUrl: {
          defaultValue: terraformRunnerUrl
          type: 'String'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          operationOptions: 'EnableSchemaValidation'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                requestId: {
                  type: 'string'
                }
                projectName: {
                  type: 'string'
                }
                environment: {
                  type: 'string'
                }
                managementGroup: {
                  type: 'string'
                }
                billingProfile: {
                  type: 'string'
                }
                budget: {
                  type: 'number'
                }
                region: {
                  type: 'string'
                }
                requiredApprovals: {
                  type: 'array'
                }
              }
            }
          }
        }
      }
      actions: {
        Initialize_Request_Status: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'requestStatus'
                type: 'string'
                value: 'Received'
              }
            ]
          }
        }
        Response_Request_Accepted: {
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 200
            body: {
              message: 'Subscription vending request accepted.'
              requestId: '@triggerBody()?[''requestId'']'
              projectName: '@triggerBody()?[''projectName'']'
              status: '@variables(''requestStatus'')'
            }
          }
          runAfter: {
            Initialize_Request_Status: [
              'Succeeded'
            ]
          }
        }
      }
    }
    parameters: {
      azureWOWResourceId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/serverfarms/${appServicePlan.name}'
    }
  }
  dependsOn: [
    storageAccount
  ]
}

output logicAppName string = logicApp.name
output logicAppResourceId string = logicApp.id
output storageAccountName string = storageAccount.name
