targetScope = 'subscription'

@description('Specifies the location/region for resources.')
param rgName string
param location string = 'eastus'

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rgName
  location: location
}
