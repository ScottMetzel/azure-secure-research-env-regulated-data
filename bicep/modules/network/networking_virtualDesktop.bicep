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
// Azure Bastion requires specific inbound/outbound rules.
// See: https://learn.microsoft.com/azure/bastion/bastion-nsg

resource AzureBastionNSG 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${environmentName}-NSG-Bastion-01'
  location: location
  tags: tags
  properties: {
    securityRules: [
      // ── Inbound ──────────────────────────────────────────────────────────────
      {
        name: 'Allow-HTTPS-Inbound-Internet'
        properties: {
          priority: 120
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow HTTPS from the internet (Bastion portal access).'
        }
      }
      {
        name: 'Allow-GatewayManager-Inbound'
        properties: {
          priority: 130
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow Azure Gateway Manager control plane traffic.'
        }
      }
      {
        name: 'Allow-AzureLoadBalancer-Inbound'
        properties: {
          priority: 140
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow Azure Load Balancer health probes.'
        }
      }
      {
        name: 'Allow-BastionHostCommunication-Inbound'
        properties: {
          priority: 150
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: ['8080', '5701']
          description: 'Allow Bastion host-to-host communication.'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic.'
        }
      }
      // ── Outbound ─────────────────────────────────────────────────────────────
      {
        name: 'Allow-RDP-SSH-Outbound-VNet'
        properties: {
          priority: 100
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: ['22', '3389']
          description: 'Allow RDP and SSH outbound to VNet targets.'
        }
      }
      {
        name: 'Allow-AzureCloud-HTTPS-Outbound'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
          description: 'Allow outbound HTTPS to Azure Cloud for Bastion control plane.'
        }
      }
      {
        name: 'Allow-BastionHostCommunication-Outbound'
        properties: {
          priority: 120
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: ['8080', '5701']
          description: 'Allow Bastion host-to-host outbound communication.'
        }
      }
      {
        name: 'Allow-GetSessionInfo-Outbound'
        properties: {
          priority: 130
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: ['80', '443']
          description: 'Allow session information retrieval (certificate validation, etc.).'
        }
      }
      {
        name: 'Deny-All-Outbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other outbound traffic from Bastion subnet.'
        }
      }
    ]
  }
}

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
          networkSecurityGroup: { id: AzureBastionNSG.id }
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
output vnetId string = virtualDesktopVNET.id

@description('The name of the virtual network.')
output vnetName string = virtualDesktopVNET.name

@description('The resource ID of the Azure Bastion subnet.')
output AzureBastionSubnetId string = virtualDesktopVNET.properties.subnets[0].id

@description('The resource ID of the Web01 subnet.')
output Web01SubnetId string = virtualDesktopVNET.properties.subnets[1].id

@description('The resource ID of the App01 subnet.')
output App01SubnetId string = virtualDesktopVNET.properties.subnets[2].id

@description('The resource ID of the DB01 subnet.')
output DB01SubnetId string = virtualDesktopVNET.properties.subnets[3].id

@description('The resource ID of the Storage01 subnet.')
output Storage01SubnetId string = virtualDesktopVNET.properties.subnets[4].id

@description('The resource ID of the WebVNETIntegration01 subnet.')
output WebVNETIntegration01SubnetId string = virtualDesktopVNET.properties.subnets[5].id

@description('The resource ID of the RDServer01 subnet.')
output RDServer01SubnetId string = virtualDesktopVNET.properties.subnets[6].id

@description('The resource ID of the AVD01 subnet.')
output AVD01SubnetId string = virtualDesktopVNET.properties.subnets[7].id
