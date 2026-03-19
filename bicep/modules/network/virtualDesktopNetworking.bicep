@description('Azure region for all network resources.')
param location string

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Tags to apply to all resources.')
param tags object

@description('Address prefix for the virtual network.')
param vnetAddressPrefix string = '10.100.40.0/21'

@description('Address prefix for the Azure Bastion subnet.')
param bastionSubnetPrefix string = '10.100.40.0/26'

param webSubnetPrefix string = '10.100.40.64/27'
param appSubnetPrefix string = '10.100.40.96/27'
param dbSubnetPrefix string = '10.100.40.128/27'
@description('Address prefix for the storage subnet, used with Azure Storage Accounts and FSLogix.')
param storageSubnetPrefix string = '10.100.40.160/27'

param webVNETIntegrationSubnetPrefix string = '10.100.40.192/27'

@description('Address prefix for the Remote Desktop Server subnet.')
param rdServerSubnetPrefix string = '10.100.41.0/24'

@description('Address prefix for the first Azure Virtual Desktop subnet.')
param avdSubnetPrefix string = '10.100.42.0/24'

// ── NSGs ──────────────────────────────────────────────────────────────────────

resource RemoteDesktopNSG 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${environmentName}-NSG-RemoteDesktop-01'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

// ── Virtual Network ───────────────────────────────────────────────────────────

resource virtualDesktopVNET 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: '${environmentName}-VNET-RemoteDesktop-01'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
          networkSecurityGroup: { id: RemoteDesktopNSG.id }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'Web01'
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: { id: RemoteDesktopNSG.id }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: []
        }
      }
      {
        name: 'App01'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: { id: RemoteDesktopNSG.id }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: []
        }
      }
      {
        name: 'DB01'
        properties: {
          addressPrefix: dbSubnetPrefix
          networkSecurityGroup: { id: RemoteDesktopNSG.id }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: []
        }
      }
      {
        name: 'Storage01'
        properties: {
          addressPrefix: storageSubnetPrefix
          networkSecurityGroup: { id: RemoteDesktopNSG.id }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: []
        }
      }
      {
        name: 'WebVNETIntegration01'
        properties: {
          addressPrefix: webVNETIntegrationSubnetPrefix
          networkSecurityGroup: { id: RemoteDesktopNSG.id }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: []
        }
      }
      {
        name: 'RDServer01'
        properties: {
          addressPrefix: rdServerSubnetPrefix
          networkSecurityGroup: { id: RemoteDesktopNSG.id }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'AVD01'
        properties: {
          addressPrefix: avdSubnetPrefix
          networkSecurityGroup: { id: RemoteDesktopNSG.id }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: []
        }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the virtual network.')
output vnetId string = vnet.id

@description('The name of the virtual network.')
output vnetName string = vnet.name

@description('The resource ID of the compute subnet.')
output computeSubnetId string = vnet.properties.subnets[0].id

@description('The resource ID of the private endpoint subnet.')
output privateEndpointSubnetId string = vnet.properties.subnets[1].id

@description('The resource ID of the data integration subnet.')
output dataIntegrationSubnetId string = vnet.properties.subnets[2].id
