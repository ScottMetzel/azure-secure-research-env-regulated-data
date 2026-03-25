targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@minLength(1)
@maxLength(20)
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

@description('Azure DNS Private Resolver Inbound Endpoint Static Private IP Address. Must be within the address range of the AzDNSPRInbound01 subnet defined in the hub virtual network.')
param azDNSPRInboundStaticIP string = '10.10.10.10'

param privateDnsZoneNamesArray array = [
  'privatelink.vaultcore.azure.net'
  'privatelink.datafactory.azure.net'
  'privatelink.azureml.ms'
]

@description('The string array of DNS servers to use on the Virtual Network.')
param vNETDNSServers array = [
  '168.63.129.16'
]

@description('Tags applied to every resource.')
param tags object = {
  WorkloadName: 'SRERD'
  Environment: 'Dev'
}

// ── Variables ───────────────────────────────────────────────────────────
var firewallPolicyDNSServers = array(azDNSPRInboundStaticIP)
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
    vNETDNSServers: vNETDNSServers
    hubVNETAddressPrefix: hubVNETAddressPrefix
    gatewaySubnetPrefix: gatewaySubnetPrefix
    firewallSubnetPrefix: firewallSubnetPrefix
    azDNSPrivateResolverInboundSubnet: azDNSPrivateResolverInboundSubnet
    azDNSPrivateResolverOutboundSubnet: azDNSPrivateResolverOutboundSubnet
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
    dnsServers: firewallPolicyDNSServers
  }
}

// ── Hub VNet DNS Zone Links (network-rg, where DNS zones live) ────────────────
// Creates additional VNet links so the research VM in the hub can resolve
// private endpoint DNS names (storage, Key Vault, ADF, etc.).
module hubPrivateDnsZonesAndLinks '../network/privateDNSZonesAndLinks.bicep' = {
  name: 'hubPrivateDnsZonesAndLinks'
  scope: resourceGroup(privateDNSZonesRG.name)
  params: {
    location: location
    vnetId: hubVNET.outputs.VNETid
    privateDnsZoneNamesArray: privateDnsZoneNamesArray
    tags: tags
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

@description('The name of the resource group containing the Azure Private DNS Zones linked to the hub VNET.')
output privateDNSZonesRGName string = privateDNSZonesRG.name

@description('The array of Azure Private DNS Zone RResource IDs linked to the hub VNET.')
output privateDNSZoneIds array = hubPrivateDnsZonesAndLinks.outputs.privateDnsZoneIds

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
