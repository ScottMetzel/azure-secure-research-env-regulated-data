@description('Azure region for all hub network resources.')
param location string

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Tags to apply to all resources.')
param tags object

@description('Address prefix for the hub virtual network.')
param hubVnetAddressPrefix string = '10.100.0.0/23'

@description('Address prefix for AzureFirewallSubnet (minimum /26).')
param firewallSubnetPrefix string = '10.100.0.0/26'

@description('Address prefix for Azure DNS Private Resolver Inbound Subnet (minimum /28).')
param azDNSPrivateResolverInboundSubnet string = '10.100.0.64/28'

@description('Address prefix for Azure DNS Private Resolver Outbound Subnet (minimum /28).')
param azDNSPrivateResolverOutboundSubnet string = '10.100.0.80/28'
// ── Hub Virtual Network ───────────────────────────────────────────────────────
// AzureFirewallSubnet and AzureBastionSubnet are reserved names required by Azure.

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: '${environmentName}-VNET-Hub-01'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [hubVnetAddressPrefix]
    }
    subnets: [
      {
        // Azure Firewall requires this exact subnet name and a /26 minimum prefix.
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        // Azure DNS Private Resolver Inbound Subnet
        name: 'AzDNSPRInbound01'
        properties: {
          addressPrefix: azDNSPrivateResolverInboundSubnet
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        // Azure DNS Private Resolver Outbound Subnet
        name: 'AzDNSPROutbound01'
        properties: {
          addressPrefix: azDNSPrivateResolverOutboundSubnet
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the hub virtual network.')
output VNETid string = hubVnet.id

@description('The name of the hub virtual network.')
output VNETName string = hubVnet.name

@description('The resource ID of AzureFirewallSubnet.')
output firewallSubnetId string = hubVnet.properties.subnets[0].id

@description('The resource ID of AzDNSPRInbound01 subnet.')
output azDNSPRInboundSubnetId string = hubVnet.properties.subnets[1].id

@description('The resource ID of AzDNSPROutbound01 subnet.')
output azDNSPROutboundSubnetId string = hubVnet.properties.subnets[2].id
