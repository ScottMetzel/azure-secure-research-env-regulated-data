targetScope = 'subscription'

@description('Azure region for all resources.')
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

@description('Hub VNET Resource ID')
param net_hub_vnetId string = '/subscriptions/00000-0000-0000-0000-000000000000/resourceGroups/Prod-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Prod-VNET-Hub-01'

@description('Hub VNET DNS Private Resolver Inbound Subnet ID')
param net_hub_azDNSPRInboundSubnetId string = '/subscriptions/00000-0000-0000-0000-000000000000/resourceGroups/Prod-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Prod-VNET-Hub-01/subnets/AzDNSPRInbound01'

@description('Azure DNS Private Resolver Inbound Endpoint Static Private IP Address. Must be within the address range of the AzDNSPRInbound01 subnet defined in the hub virtual network.')
param net_hub_azDNSPRInboundStaticIP string = '10.10.10.10'

@description('The date and time in UTC format. Used as part of the deployment name')
param deploymentTimestamp string = utcNow()

@description('Tags applied to every resource.')
param tags object = {
  WorkloadName: 'SRERD'
  Environment: 'Dev'
}

// ── Resource Groups ───────────────────────────────────────────────────────────
@description('Azure Private DNS Resolver Resource Group - contains the Azure Private DNS Resolver resources.')
resource privateDNSResolverRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-PrivateDNSResolver-01'
  location: location
  tags: tags
}

// ── Resources via Modules ───────────────────────────────────────────────────────────
@description('Azure Private DNS Resolver')
module privateDNSResolver '../network/privateDNSResolver.bicep' = {
  name: 'privateDNSResolver_${deploymentTimestamp}'
  scope: resourceGroup(privateDNSResolverRG.name)
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    vnetId: net_hub_vnetId
    azDNSPRInboundSubnetId: net_hub_azDNSPRInboundSubnetId
    azDNSPRInboundStaticIP: net_hub_azDNSPRInboundStaticIP
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
@description('The resource ID of the Azure Private DNS Resolver.')
output privateDNSResolverId string = privateDNSResolver.outputs.privateDNSResolverId

@description('The name of the Azure Private DNS Resolver.')
output privateDNSResolverName string = privateDNSResolver.outputs.privateDNSResolverName
