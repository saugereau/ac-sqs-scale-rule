// ******************
// ** Parameters
// ******************

param location string = resourceGroup().location
param projectName string
@secure()
param awsAccessKeyId string
@secure()
param awsSecretAccessKey string

// ******************
// ** Variables
// ******************

var ContainerAppEnvironmentName = toLower('${projectName}-cae')
var AppInsightsName = toLower('${projectName}-appi')
var AppName = toLower('${projectName}-api')
var ManagedIdentityName = toLower('${projectName}-id')
var AcrName = replace(('${projectName}-acr'), '-', '')
var SqlServerName = toLower('${projectName}-sql')
var DatabaseName = toLower('${projectName}-sqldb')


// ******************
// ** Resources
// ******************

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: AppInsightsName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: AcrName
}

resource cae 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: ContainerAppEnvironmentName
}

resource sqlServer 'Microsoft.Sql/servers@2024-05-01-preview' existing = {
  name: SqlServerName
}


resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: ManagedIdentityName
}


resource app 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: AppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: cae.id
    configuration: {
      registries: [
        {
          server: acr.properties.loginServer
          identity: managedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'accountsub-aws-access-key-id'
          value: awsAccessKeyId
        }
        {
          name: 'accountsub-aws-secret-access-key'
          value: awsSecretAccessKey
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'main'
          image: '${acr.properties.loginServer}/demo-api:latest'
          env: [
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
            {
              name: 'ACCOUNTSUB_AWS_ACCESS_KEY_ID'
              secretRef: 'accountsub-aws-access-key-id'
            }
            {
              name: 'ACCOUNTSUB_AWS_SECRET_ACCESS_KEY'
              secretRef: 'accountsub-aws-secret-access-key'
            }
            {
              name: 'SQLCONNSTR_DefaultConnection'
              value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName};Database=${DatabaseName};Authentication=Active Directory Default;User Id=${managedIdentity.properties.clientId};Connection Timeout=30;'
            }
          ]
          
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health/live'
                port: 8080
              }
              initialDelaySeconds: 1
              periodSeconds: 10
              timeoutSeconds: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health/ready'
                port: 8080
              }
              periodSeconds: 10
              timeoutSeconds: 5
            }
          ]
        }
      ]
      scale: {
        cooldownPeriod: 500
        maxReplicas: 3
        minReplicas: 1
        pollingInterval: 5
        rules: [
          {
            name: 'sqstrigger-rule'
            custom: {
              auth: [
                {
                  secretRef: 'accountsub-aws-access-key-id'
                  triggerParameter: 'awsAccessKeyID'
                }
                {
                  secretRef: 'accountsub-aws-secret-access-key'
                  triggerParameter: 'awsSecretAccessKey'
                }

              ]
              metadata: {
                queueURL: 'https://sqs.eu-west-1.amazonaws.com/270463983390/sqsjobpoc_account-domain-events_poc-event-received'
                queueLength: '100'
                awsRegion: 'eu-west-1'
                activationQueueLength: '0'
                scaleOnInFlight: 'false'
              }
              type: 'aws-sqs-queue'
            }
          }
        ]
      }
    }
  }
}
