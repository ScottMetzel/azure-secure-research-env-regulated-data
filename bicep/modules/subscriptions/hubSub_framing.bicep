targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Prod'

@description('Hub VNET Resource ID')
param net_hub_vnetId string = '/subscriptions/00000-0000-0000-0000-000000000000/resourceGroups/Prod-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Prod-VNET-Hub-01'

@description('Hub VNET Azure Firewall Subnet ID')
param net_hub_firewallSubnetId string = '/subscriptions/00000-0000-0000-0000-000000000000/resourceGroups/Prod-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Prod-VNET-Hub-01/subnets/AzureFirewallSubnet'

@description('The Resource ID of the Log Analytics Workspace to link for monitoring. This should be the workspace deployed in the hub subscription.')
param logAnalyticsWorkspaceId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/prod-rg-SOC-01/providers/microsoft.operationalinsights/workspaces/prod-law-soc-01'

@description('Remote Desktop Resource ID')
param remoteDesktopVnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-RemoteDesktop-01'

@description('Resource ID of the Rearcher VNET')
param researcherVnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Researcher-01'

@description('Azure DNS Private Resolver Inbound Endpoint Static Private IP Address. Must be within the address range of the AzDNSPRInbound01 subnet defined in the hub virtual network.')
param net_hub_azDNSPRInboundStaticIP string = '10.10.10.10'

param privateDnsZoneNamesArray array = [
  'privatelink.vaultcore.azure.net'
  'privatelink.datafactory.azure.net'
  'privatelink.azureml.ms'
]

@description('The private IP address of the Azure Firewall deployed in the hub, used as the next hop for forced tunneling from the Remote Desktop Server subnet.')
param net_hub_azureFirewallPrivateIP string = '10.100.0.4'

@description('The date and time in UTC format. Used as part of the deployment name')
param deploymentTimestamp string = utcNow()

@description('Tags applied to every resource.')
param tags object = {
  WorkloadName: 'SRERD'
  Environment: 'Dev'
}

// ── Variables ───────────────────────────────────────────────────────────
var net_hub_VNETName = last(split(net_hub_vnetId, '/'))
var net_hub_VNETRGName = split(net_hub_vnetId, '/')[4]

var firewallPolicyDNSServers = array(net_hub_azDNSPRInboundStaticIP)

var net_remoteDesktop_VNETName = last(split(remoteDesktopVnetId, '/'))

var net_researcher_VNETName = last(split(researcherVnetId, '/'))
// ── Resource Groups ───────────────────────────────────────────────────────────
@description('Azure Private DNS Zones Resource Group - contains the Azure Private DNS Zones linked to the hub VNET.')
resource privateDNSZonesRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-PrivateDNSZones-01'
  location: location
  tags: tags
}

// ── Resources via Modules ─────────────────────────────────────────────────────
module hubtoVirtualDesktopSpokePeering '../network/vnetPeering.bicep' = {
  name: 'hubtoVirtualDesktopSpokePeering_${deploymentTimestamp}'
  scope: resourceGroup(net_hub_VNETRGName)
  params: {
    localVnetName: net_hub_VNETName
    remoteVnetName: net_remoteDesktop_VNETName
    remoteVnetId: remoteDesktopVnetId
  }
}

module hubtoResearcherSpokePeering '../network/vnetPeering.bicep' = {
  name: 'hubtoResearcherSpokePeering_${deploymentTimestamp}'
  scope: resourceGroup(net_hub_VNETRGName)
  params: {
    localVnetName: net_hub_VNETName
    remoteVnetName: net_researcher_VNETName
    remoteVnetId: researcherVnetId
  }
}

@description('Azure Firewall Policy and Firewall')
module firewallandPolicy '../network/firewall.bicep' = {
  name: 'hubFirewall_${deploymentTimestamp}'
  scope: resourceGroup(net_hub_VNETRGName)
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    firewallSubnetId: net_hub_firewallSubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    dnsServers: firewallPolicyDNSServers
    net_hub_azDNSPRInboundStaticIP: net_hub_azDNSPRInboundStaticIP
    net_hub_azureFirewallPrivateIP: net_hub_azureFirewallPrivateIP
  }
}

module hubPrivateDnsZonesAndLinks '../network/privateDNSZonesAndLinks.bicep' = {
  name: 'hubPrivateDnsZonesAndLinks_${deploymentTimestamp}'
  scope: resourceGroup(privateDNSZonesRG.name)
  params: {
    location: location
    vnetId: net_hub_vnetId
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

@description('The name of the resource group containing the Azure Private DNS Zones linked to the hub VNET.')
output privateDNSZonesRGName string = privateDNSZonesRG.name

@description('The array of Azure Private DNS Zone RResource IDs linked to the hub VNET.')
output privateDNSZoneIds array = hubPrivateDnsZonesAndLinks.outputs.privateDnsZoneIds
