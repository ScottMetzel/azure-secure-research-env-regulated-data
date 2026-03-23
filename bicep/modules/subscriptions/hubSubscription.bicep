targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Prod'

@description('Tags applied to every resource.')
param tags object = {
  workloadName: 'SILO'
  environment: environmentName
}

@description('Azure DNS Private Resolver Inbound Endpoint Static Private IP Address. Must be within the address range of the AzDNSPRInbound01 subnet defined in the hub virtual network.')
param azDNSPRInboundStaticIP string = '10.100.0.68'

// ── Resource Groups ───────────────────────────────────────────────────────────
@description('Hub VNET resource group — contains the hub Virtual Network and Firewall.')
resource hubVNETRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-NetworkInfrastructure-01'
  location: location
  tags: tags
}

@description('Azure Private DNS Resolver Resource Group - contains the Azure Private DNS Resolver resources.')
resource privateDNSResolverRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-PrivateDNSResolver-01'
  location: location
  tags: tags
}

@description('Azure Private DNS Zones Resource Group - contains the Azure Private DNS Zones linked to the hub VNET.')
resource privateDNSZonesRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-PrivateDNSZones-01'
  location: location
  tags: tags
}

@description('Microsoft Sentinel Resource Group.')
resource sentinelRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-Sentinel-01'
  location: location
  tags: tags
}

// ── Resources via Modules ───────────────────────────────────────────────────────────
module hubVNET '../network/networking_hub.bicep' = {
  name: 'hubVNET'
  scope: resourceGroup(hubVNETRG.name)
  params: {
    location: location
    environmentName: environmentName
    tags: tags
  }
}

module logAnalytics '../monitoring/logAnalytics.bicep' = {
  name: 'logAnalytics'
  scope: resourceGroup(sentinelRG.name)
  params: {
    location: location
    environmentName: environmentName
    workspaceName: '${environmentName}-LAW-SOC-01'
    tags: tags
  }
}

@description('Azure Firewall Policy and Firewall')
module firewallandPolicy '../network/firewall.bicep' = {
  name: 'hubFirewall'
  scope: resourceGroup(hubVNETRG.name)
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    firewallSubnetId: hubVNET.outputs.firewallSubnetId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceResourceId
  }
}

@description('Azure Private DNS Resolver')
module privateDNSResolver '../network/privateDNSResolver.bicep' = {
  name: 'privateDNSResolver'
  scope: resourceGroup(privateDNSResolverRG.name)
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    azDNSPRInboundSubnetId: hubVNET.outputs.azDNSPRInboundSubnetId
    azDNSPRInboundStaticIP: azDNSPRInboundStaticIP
  }
}

// ── Hub VNet DNS Zone Links (network-rg, where DNS zones live) ────────────────
// Creates additional VNet links so the research VM in the hub can resolve
// private endpoint DNS names (storage, Key Vault, ADF, etc.).

module hubDnsZoneLinks '../network/privateDNSZones.bicep' = {
  name: 'hubDnsZoneLinks'
  scope: resourceGroup(privateDNSZonesRG.name)
  params: {
    environmentName: environmentName
    tags: tags
    vnetId: hubVNET.outputs.VNETid
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
@description('The resource ID of the Azure Firewall.')
output firewallId string = firewallandPolicy.outputs.firewallId

@description('The name of the Azure Firewall.')
output firewallName string = firewallandPolicy.outputs.firewallName

@description('The private IP address of the Azure Firewall.')
output firewallPrivateIp string = firewallandPolicy.outputs.firewallPrivateIp

@description('The resource ID of the Azure Private DNS Resolver.')
output privateDNSResolverId string = privateDNSResolver.outputs.privateDNSResolverId

@description('The name of the Azure Private DNS Resolver.')
output privateDNSResolverName string = privateDNSResolver.outputs.privateDNSResolverName

@description('The resource ID of the Log Analytics Workspace.')
output logAnalyticsWorkspaceResourceId string = logAnalytics.outputs.workspaceResourceId

@description('The name of the Log Analytics Workspace.')
output logAnalyticsWorkspaceName string = logAnalytics.outputs.workspaceName

@description('The name of the hub virtual network resource group.')
output hubVNETRGName string = hubVNETRG.name

@description('Hub VNET Resource ID')
output hubVNETId string = hubVNET.outputs.VNETid

@description('Hub VNET Name')
output hubVNETName string = hubVNET.outputs.VNETName
