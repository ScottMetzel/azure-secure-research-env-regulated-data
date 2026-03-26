@description('Azure region for all hub network resources.')
param location string = 'westus2'

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Dev'

@description('Resource ID of the Virtual Network the Private Resolver will be deployed into.')
param vnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Hub-01'

@description('Subnet ID for the Azure Private DNS Resolver Inbound Endpoint.')
param azDNSPRInboundSubnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Hub-01/subnets/AzDNSPRInbound01'

@description('Azure DNS Private Resolver Inbound Endpoint Static Private IP Address. Must be within the address range of the AzDNSPRInbound01 subnet defined in the hub virtual network.')
param azDNSPRInboundStaticIP string = '10.100.1.42'

@description('Tags to apply to all resources.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}

// ── Resources ─────────────────────────────────────────────────────────
@description('Azure Private DNS Resolver')
resource privateDNSResolver 'Microsoft.Network/dnsResolvers@2025-05-01' = {
  name: '${environmentName}-DNSPR-Core-01'
  location: location
  tags: tags
  properties: {
    virtualNetwork: {
      id: vnetId
    }
  }
}

@description('Azure Private DNS Resolver Inbound Endpoint')
resource privateDNSResolverInboundEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2025-05-01' = {
  name: 'IE01'
  parent: privateDNSResolver
  location: location
  properties: {
    ipConfigurations: [
      {
        privateIpAddress: azDNSPRInboundStaticIP
        privateIpAllocationMethod: 'Static'
        subnet: { id: azDNSPRInboundSubnetId }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
@description('The resource ID of the Azure Private DNS Resolver.')
output privateDNSResolverId string = privateDNSResolver.id

@description('The resource ID of the Azure Private DNS Resolver Inbound Endpoint.')
output privateDNSResolverInboundEndpointId string = privateDNSResolverInboundEndpoint.id

@description('The name of the Azure Private DNS Resolver')
output privateDNSResolverName string = privateDNSResolver.name
