@description('Location for all resources deployed in the Bicep file')
param location string = resourceGroup().location

@description('ExpressRoute peering location')
// param erpeeringLocation string = 'Washington DC'
param erpeeringLocation string = 'Seattle'

@description('Name of the ExpressRoute circuit')
// param erCircuitName string = 'er-ckt01'
param erCircuitName string = 'MyExpressRoute'

@description('Name of the ExpressRoute provider')
// param serviceProviderName string = 'Equinix'
param serviceProviderName string = 'Megaport'

@description('Tier ExpressRoute circuit')
@allowed([
  'Premium'
  'Standard'
])
param erSKU_Tier string = 'Premium'

@description('Billing model ExpressRoute circuit')
@allowed([
  'MeteredData'
  'UnlimitedData'
])
param erSKU_Family string = 'MeteredData'

@description('Bandwidth ExpressRoute circuit')
@allowed([
  50
  100
  200
  500
  1000
  2000
  5000
  10000
])
param bandwidthInMbps int = 50

@description('autonomous system number used to create private peering between the customer edge router and MSEE routers')
// param peerASN int = 65001
param peerASN int = 131072

@description('point-to-point network prefix of primary link between the customer edge router and MSEE router')
// param primaryPeerAddressPrefix string = '192.168.10.16/30'
param primaryPeerAddressPrefix string = '172.18.0.32/30'

@description('point-to-point network prefix of secondary link between the customer edge router and MSEE router')
// param secondaryPeerAddressPrefix string = '192.168.10.20/30'
param secondaryPeerAddressPrefix string = '172.18.0.36/30'

@description('VLAN Id used between the customer edge routers and MSEE routers. primary and secondary link have the same VLAN Id')
// param vlanId int = 100
param vlanId int = 737

@description('name of the Virtual Network')
// param vnetName string = 'vnet1'
param vnetName string = 'expressRouteVNET'

// @description('name of the subnet')
// param subnet1Name string = 'subnet1'

@description('address space assigned to the Virtual Network')
// param vnetAddressSpace string = '10.10.10.0/24'
param vnetAddressSpace string = '10.10.78.0/25'

// @description('network prefix assigned to the subnet')
// param subnet1Prefix string = '10.10.10.0/25'

@description('network prefixes assigned to the gateway subnet. It has to be a network prefix with mask /27 or larger')
// param gatewaySubnetPrefix string = '10.10.10.224/27'
param gatewaySubnetPrefix string = '10.10.78.0/27'

@description('name of the ExpressRoute Gateway')
// param gatewayName string = 'er-gw'
param gatewayName string = 'ERCP2tstGateWay'

@description('ExpressRoute Gateway SKU')
@allowed([
  'Standard'
  'HighPerformance'
  'UltraPerformance'
  'ErGw1AZ'
  'ErGw2AZ'
  'ErGw3AZ'
])
// param gatewaySku string = 'HighPerformance'
param gatewaySku string = 'Standard'

var erSKU_Name = '${erSKU_Tier}_${erSKU_Family}'
var gatewayPublicIPName = '${gatewayName}-pubIP'

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/expressroutecircuits
resource erCircuit 'Microsoft.Network/expressRouteCircuits@2022-09-01' = {
  name: erCircuitName
  location: location
  sku: {
    name: erSKU_Name
    tier: erSKU_Tier
    family: erSKU_Family
  }
  properties: {
    serviceProviderProperties: {
      serviceProviderName: serviceProviderName
      peeringLocation: erpeeringLocation
      bandwidthInMbps: bandwidthInMbps
    }
    allowClassicOperations: false
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/expressroutecircuits
resource epeering 'Microsoft.Network/expressRouteCircuits/peerings@2022-09-01' = {
  parent: erCircuit
  name: 'AzurePrivatePeering'
  properties: {
    peeringType: 'AzurePrivatePeering'
    peerASN: peerASN
    primaryPeerAddressPrefix: primaryPeerAddressPrefix
    secondaryPeerAddressPrefix: secondaryPeerAddressPrefix
    vlanId: vlanId
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks?pivots=deployment-language-bicep
resource vnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
    ]
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses?pivots=deployment-language-bicep
resource publicIP 'Microsoft.Network/publicIPAddresses@2022-09-01' = {
  name: gatewayPublicIPName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworkgateways
resource gateway 'Microsoft.Network/virtualNetworkGateways@2022-09-01' = {
  name: gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'GatewaySubnet')
          }
          publicIPAddress: {
            id: publicIP.id
          }
        }
        name: 'gwIPconf'
      }
    ]
    gatewayType: 'ExpressRoute'
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    vpnType: 'RouteBased'
  }
  dependsOn: [
    vnet
  ]
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/connections
resource erGWConnection 'Microsoft.Network/connections@2022-09-01' = {
  name: 'ERCP2tstGWConnection'
  location: location
  properties: {
    connectionMode: 'Default'
    connectionType: 'ExpressRoute'
    dpdTimeoutSeconds: 0
    enableBgp: false
    enablePrivateLinkFastPath: false
    expressRouteGatewayBypass: false
    peer: {
      id: erCircuit.id
    }
    routingWeight: 0
    trafficSelectorPolicies: [
    ]
    useLocalAzureIpAddress: false
    usePolicyBasedTrafficSelectors: false
    virtualNetworkGateway1: {
      id: gateway.id
      properties: {
      }
    }
  }
}

output erCircuitName string = erCircuitName
output gatewayName string = gatewayName
output gatewaySku string = gatewaySku
