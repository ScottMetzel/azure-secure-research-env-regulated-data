@description('Azure region for all network resources.')
param location string

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Tags to apply to all resources.')
param tags object

@description('Address prefix for the virtual network.')
param vnetAddressPrefix string = '10.100.60.0/21'

param webSubnetPrefix string = '10.100.60.64/27'
param appSubnetPrefix string = '10.100.60.96/27'
param dbSubnetPrefix string = '10.100.60.128/27'

@description('Address prefix for the storage subnet, used with Azure Storage Accounts and FSLogix.')
param storageSubnetPrefix string = '10.100.60.160/27'

param KeyVault01SubnetPrefix string = ''

param webVNETIntegrationSubnetPrefix string = '10.100.60.192/27'

@description('Address prefix for the first Data Science Server subnet.')
param researcherServerSubnetPrefix string = '10.100.61.0/28'

@description('The private IP address of the Azure Firewall deployed in the hub, used as the next hop for forced tunneling from the Remote Desktop Server subnet.')
param azureFirewallPrivateIp string

// ── NSGs ──────────────────────────────────────────────────────────────────────

resource ResearcherNSG 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${environmentName}-NSG-Researcher-01'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

// ── Route Tables ──────────────────────────────────────────────────────────────────────
resource researcherVNETRouteTable 'Microsoft.Network/routeTables@2025-05-01' = {
  location: location
  name: '${environmentName}-RT-RemoteDesktop-01'
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'Default'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: azureFirewallPrivateIp
          nextHopType: 'VirtualAppliance'
        }
        type: 'string'
      }
    ]
  }
  tags: tags
}

// ── Virtual Network ───────────────────────────────────────────────────────────

resource researcherSpokeVNET 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: '${environmentName}-VNET-Researcher-01'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: 'Web01'
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: { id: ResearcherNSG.id }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: []
          routeTable: {
            id: researcherVNETRouteTable.id
          }
        }
      }
      {
        name: 'App01'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: { id: ResearcherNSG.id }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: []
          routeTable: {
            id: researcherVNETRouteTable.id
          }
        }
      }
      {
        name: 'DB01'
        properties: {
          addressPrefix: dbSubnetPrefix
          networkSecurityGroup: { id: ResearcherNSG.id }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: []
          routeTable: {
            id: researcherVNETRouteTable.id
          }
        }
      }
      {
        name: 'Storage01'
        properties: {
          addressPrefix: storageSubnetPrefix
          networkSecurityGroup: { id: ResearcherNSG.id }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: []
          routeTable: {
            id: researcherVNETRouteTable.id
          }
        }
      }
      {
        name: 'Secrets01'
        properties: {
          addressPrefix: KeyVault01SubnetPrefix
          networkSecurityGroup: { id: ResearcherNSG.id }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: []
          routeTable: {
            id: researcherVNETRouteTable.id
          }
        }
      }
      {
        name: 'WebVNETIntegration01'
        properties: {
          addressPrefix: webVNETIntegrationSubnetPrefix
          networkSecurityGroup: { id: ResearcherNSG.id }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          routeTable: {
            id: researcherVNETRouteTable.id
          }
          serviceEndpoints: []
        }
      }
      {
        name: 'ResearcherVMSubnet01'
        properties: {
          addressPrefix: researcherServerSubnetPrefix
          networkSecurityGroup: { id: ResearcherNSG.id }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          routeTable: {
            id: researcherVNETRouteTable.id
          }
        }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the virtual network.')
output vnetId string = researcherSpokeVNET.id

@description('The name of the virtual network.')
output vnetName string = researcherSpokeVNET.name

@description('The resource ID of the Web01 subnet.')
output Web01SubnetId string = researcherSpokeVNET.properties.subnets[0].id

@description('The resource ID of the App01 subnet.')
output App01SubnetId string = researcherSpokeVNET.properties.subnets[1].id

@description('The resource ID of the DB01 subnet.')
output DB01SubnetId string = researcherSpokeVNET.properties.subnets[2].id

@description('The resource ID of the Storage01 subnet.')
output Storage01SubnetId string = researcherSpokeVNET.properties.subnets[3].id

@description('The resource ID of the Secrets01 subnet.')
output Secrets01SubnetId string = researcherSpokeVNET.properties.subnets[4].id

@description('The resource ID of the WebVNETIntegration01 subnet.')
output WebVNETIntegration01SubnetId string = researcherSpokeVNET.properties.subnets[5].id

@description('The resource ID of the ResearcherVMSubnet01 subnet.')
output ResearcherVMSubnet01SubnetId string = researcherSpokeVNET.properties.subnets[6].id

@description('The resource ID of the NSG.')
output nsgId string = ResearcherNSG.id
