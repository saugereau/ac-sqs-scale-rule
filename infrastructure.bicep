// ******************
// ** Parameters
// ******************

param location string = resourceGroup().location
param projectName string

// ******************
// ** Variables
// ******************

var ContainerAppEnvironmentName = toLower('${projectName}-cae')
var LogAnalyticsWorkspaceName = toLower('${projectName}-log')
var AppInsightsName = toLower('${projectName}-appi')
var AcrName = replace(('${projectName}-acr'), '-', '')
var ManagedIdentityName = toLower('${projectName}-id')

// ******************
// ** Resources
// ******************

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: LogAnalyticsWorkspaceName
  location: location
  properties: {
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: AppInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 30
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: ContainerAppEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: AcrName
  location: location
  sku: {
    name: 'Standard'
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: ManagedIdentityName
  location: location
}
resource acrPullAuthorization 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, managedIdentity.id, 'AcrPull')
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    ) // AcrPull
    principalType: 'ServicePrincipal'
  }
}
