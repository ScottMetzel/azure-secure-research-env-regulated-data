@description('Azure region for all hub network resources.')
param location string

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Subnet ID for the Azure Private DNS Resolver Inbound Endpoint.')
param azDNSPRInboundSubnetId string

@description('Azure DNS Private Resolver Inbound Endpoint Static Private IP Address. Must be within the address range of the AzDNSPRInbound01 subnet defined in the hub virtual network.')
param azDNSPRInboundStaticIP string

@description('Tags to apply to all resources.')
param tags object

// ── Resources ─────────────────────────────────────────────────────────
@description('Azure Private DNS Resolver')
resource privateDNSResolver 'Microsoft.Network/privateDnsResolvers@2025-05-01' = {
  name: '${environmentName}-DNSPR-Core-01'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Standard'
    }
  }
}

@description('Azure Private DNS Resolver Inbound Endpoint')
resource privateDNSResolverInboundEndpoint 'Microsoft.Network/privateDnsResolvers/inboundEndpoints@2025-05-01' = {
  name: 'IE01'
  parent: privateDNSResolver
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IPConfig01'
        properties: {
          subnet: {
            id: azDNSPRInboundSubnetId
          }
          privateIPAddress: azDNSPRInboundStaticIP
          privateIPAllocationMethod: 'Static'
        }
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
