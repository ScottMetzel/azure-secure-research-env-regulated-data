@description('Azure region for all hub network resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@allowed([
  'Demo'
  'Dev'
  'Test'
  'Staging'
  'Prod'
])
param environmentName string = 'Prod'

@description('Address prefix for the hub virtual network.')
param hubVNETAddressPrefix string = '10.100.0.0/23'

@description('Address prefix for the GatewaySubnet (minimum /28).')
param gatewaySubnetPrefix string = '10.100.0.0/26'

@description('Address prefix for AzureFirewallSubnet (minimum /26).')
param firewallSubnetPrefix string = '10.100.0.64/26'

@description('Address prefix for Azure DNS Private Resolver Inbound Subnet (minimum /28).')
param azDNSPrivateResolverInboundSubnet string = '10.100.0.128/28'

@description('Address prefix for Azure DNS Private Resolver Outbound Subnet (minimum /28).')
param azDNSPrivateResolverOutboundSubnet string = '10.100.0.144/28'

@description('The string array of DNS servers to use on the Virtual Network.')
param vNETDNSServers array = [
  '168.63.129.16' // Example: IP address of an internal DNS forwarder or resolver in the hub VNet. This should be updated to the actual DNS server(s) used in the environment for name resolution.
]

@description('Tags to apply to all resources.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}
// ── NSGs ──────────────────────────────────────────────────────────────────────

resource DNSPrivateResolverNSG 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${environmentName}-NSG-DNSPrivateResolver-01'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}
// ── Hub Virtual Network ───────────────────────────────────────────────────────
// AzureFirewallSubnet and AzureBastionSubnet are reserved names required by Azure.

resource hubVNET 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: '${environmentName}-VNET-Hub-01'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [hubVNETAddressPrefix]
    }
    dhcpOptions: {
      dnsServers: vNETDNSServers
    }
    subnets: [
      {
        // Azure Firewall requires this exact subnet name and a /26 minimum prefix.
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
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
          delegations: [
            {
              name: 'AzDNSPRInbound01-Delegation'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
          networkSecurityGroup: {
            id: DNSPrivateResolverNSG.id
          }
        }
      }
      {
        // Azure DNS Private Resolver Outbound Subnet
        name: 'AzDNSPROutbound01'
        properties: {
          addressPrefix: azDNSPrivateResolverOutboundSubnet
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations: [
            {
              name: 'AzDNSPROutbound01-Delegation'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
          networkSecurityGroup: {
            id: DNSPrivateResolverNSG.id
          }
        }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the hub virtual network.')
output HubVNETid string = hubVNET.id

@description('The name of the hub virtual network.')
output HubVNETName string = hubVNET.name

@description('The resource ID of AzureFirewallSubnet.')
output HubFirewallSubnetId string = hubVNET.properties.subnets[1].id

@description('The resource ID of AzDNSPRInbound01 subnet.')
output HubDNSPRInboundSubnetId string = hubVNET.properties.subnets[2].id

@description('The resource ID of AzDNSPROutbound01 subnet.')
output HubDNSPROutboundSubnetId string = hubVNET.properties.subnets[3].id
