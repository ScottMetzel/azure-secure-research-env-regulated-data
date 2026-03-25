targetScope = 'subscription'

// ── Parameters ────────────────────────────────────────────────────────────────

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@allowed([
  'Dev'
  'Test'
  'Staging'
  'Prod'
])
param environmentName string = 'Prod'

@description('Tag - Workload Name.')
param workloadName string = 'SRERD'

@description('Tag - Solution Owner.')
param solutionOwner string = 'owner@example.com'

@description('Local administrator username for VMs.')
param adminUsername string = 'azureuser'

@description('Local administrator password for VMs.')
@secure()
param adminPassword string = ''

@description('Options: Bastion or AVD. Determines whether to deploy Azure Bastion with a virtual machine or Azure Virtual Desktop for remote access to the environment. Default is Bastion.')
@allowed([
  'Bastion'
  'AVD'
])
param BastionOrAVD string = 'Bastion'

@description('Subscription ID where the research environment will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param researcherSubscriptionID string = '00000000-0000-0000-0000-000000000000'

@description('Subscription ID where the hub VNet (with Firewall) will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param hubSubscriptionID string = '00000000-0000-0000-0000-000000000000'

@description('Subscription ID where the Bastion and virtual desktop environment will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param virtualDesktopSubscriptionID string = '00000000-0000-0000-0000-000000000000'

@description('VM size for Data Science VMs.')
param researcherVMSize string = 'Standard_D4ds_v5'

@description('Number of Data Science VMs.')
@minValue(1)
@maxValue(1)
param researcherVMCount int = 1

@description('The email address of the data approver, who will receive notifications and approval requests when researchers attempt to upload data to the secure environment.')
param dataApproverEmail string = 'dataapprover@example.com'

#disable-next-line no-hardcoded-env-urls
param blobPrivateLinkZoneName string = 'privatelink.blob.core.windows.net'

param privateDnsZoneNames array = [
  'privatelink.vaultcore.azure.net'
  'privatelink.datafactory.azure.net'
  'privatelink.azureml.ms'
]

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

// ── Variables ───────────────────────────────────────────────────────────
var privateDnsZoneNamesArray = concat([blobPrivateLinkZoneName], privateDnsZoneNames)

var blobStoragePrivateDnsZoneId = resourceId(
  hubSubscriptionID,
  hubSubscription.outputs.privateDNSZonesRGName,
  'Microsoft.Network/privateDnsZones',
  blobPrivateLinkZoneName
)

var keyVaultPrivateDnsZoneId = resourceId(
  hubSubscriptionID,
  hubSubscription.outputs.privateDNSZonesRGName,
  'Microsoft.Network/privateDnsZones',
  'privatelink.vaultcore.azure.net'
)

var dataFactoryPrivateDnsZoneId = resourceId(
  hubSubscriptionID,
  hubSubscription.outputs.privateDNSZonesRGName,
  'Microsoft.Network/privateDnsZones',
  'privatelink.datafactory.azure.net'
)

var azureMLPrivateDnsZoneId = resourceId(
  hubSubscriptionID,
  hubSubscription.outputs.privateDNSZonesRGName,
  'Microsoft.Network/privateDnsZones',
  'privatelink.azureml.ms'
)

@description('Azure DNS Private Resolver Inbound Endpoint Static Private IP Address. Must be within the address range of the AzDNSPRInbound01 subnet defined in the hub virtual network.')
var azDNSPRInboundStaticIPCIDR = cidrSubnet(azDNSPrivateResolverInboundSubnet, 32, 4)

var azDNSPRInboundStaticIP = first(split(azDNSPRInboundStaticIPCIDR, '/'))

@description('Azure Firewall Private IP Address. This is the 5th usable IP in the AzureFirewallSubnet.')
var firewallPrivateIPCIDR = cidrSubnet(firewallSubnetPrefix, 32, 4)

var firewallPrivateIP = first(split(firewallPrivateIPCIDR, '/'))

var vNETDNSServers = [
  firewallPrivateIP
]

@description('Tags applied to every resource.')
var tags = {
  Description: 'Secure Research Environment for Regulated Data'
  Environment: environmentName
  Owner: solutionOwner
  WorkloadName: workloadName
}

// ── Subscription deployments ───────────────────────────────────────────────────────────

@description('Hub Subscription - Contains the hub VNET and Azure Firewall.')
module hubSubscription 'modules/subscriptions/hubSubscription.bicep' = {
  name: 'hubSubscription'
  scope: subscription(hubSubscriptionID)
  params: {
    location: location
    environmentName: environmentName
    privateDnsZoneNamesArray: privateDnsZoneNamesArray
    vNETDNSServers: vNETDNSServers
    hubVNETAddressPrefix: hubVNETAddressPrefix
    gatewaySubnetPrefix: gatewaySubnetPrefix
    firewallSubnetPrefix: firewallSubnetPrefix
    azDNSPrivateResolverInboundSubnet: azDNSPrivateResolverInboundSubnet
    azDNSPrivateResolverOutboundSubnet: azDNSPrivateResolverOutboundSubnet
    azDNSPRInboundStaticIP: azDNSPRInboundStaticIP
    tags: tags
  }
}

@description('Virtual Desktop Subscription - Contains the Bastion and VM or Azure Virtual Desktop environment.')
module virtualDesktopSubscription 'modules/subscriptions/virtualDesktopSubscription.bicep' = {
  name: 'virtualDesktopSubscription'
  scope: subscription(virtualDesktopSubscriptionID)
  params: {
    location: location
    environmentName: environmentName
    BastionOrAVD: BastionOrAVD
    vNETDNSServers: vNETDNSServers
    adminUsername: adminUsername
    adminPassword: adminPassword
    logAnalyticsWorkspaceId: hubSubscription.outputs.logAnalyticsWorkspaceResourceId
    azureFirewallPrivateIp: hubSubscription.outputs.firewallPrivateIp
    tags: tags
  }
}

@description('Researcher Subscription - Contains the research VM, compute resources, and data storage.')
module researcherSubscription 'modules/subscriptions/researcherSubscription.bicep' = {
  name: 'researcherSubscription'
  scope: subscription(researcherSubscriptionID)
  params: {
    location: location
    environmentName: environmentName
    vNETDNSServers: vNETDNSServers
    adminUsername: adminUsername
    adminPassword: adminPassword
    researcherVMSize: researcherVMSize
    researcherVMCount: researcherVMCount
    dataApproverEmail: dataApproverEmail
    logAnalyticsWorkspaceId: hubSubscription.outputs.logAnalyticsWorkspaceResourceId
    azureFirewallPrivateIp: hubSubscription.outputs.firewallPrivateIp
    blobStoragePrivateDnsZoneId: blobStoragePrivateDnsZoneId
    keyVaultPrivateDnsZoneId: keyVaultPrivateDnsZoneId
    dataFactoryPrivateDnsZoneId: dataFactoryPrivateDnsZoneId
    azureMLPrivateDnsZoneId: azureMLPrivateDnsZoneId
    tags: tags
  }
}

// ── VNet Peerings ─────────────────────────────────────────────────────────────
// Peerings are deployed as separate modules to avoid a circular dependency
// between the hub and spoke VNet modules.

module hubtoVirtualDesktopSpokePeering 'modules/subscriptions/hubSubscriptionVnetPeering.bicep' = {
  name: 'hubtoVirtualDesktopSpokePeering'
  scope: subscription(hubSubscriptionID)
  params: {
    hubVnetRgName: hubSubscription.outputs.hubVNETRGName
    hubVnetName: hubSubscription.outputs.hubVNETName
    remoteDesktopVnetName: virtualDesktopSubscription.outputs.rdVnetName
    remoteDesktopVnetId: virtualDesktopSubscription.outputs.rdVnetId
    researcherVnetId: researcherSubscription.outputs.researcherVnetId
    researcherVnetName: researcherSubscription.outputs.researcherVnetName
  }
}

module virtualDesktopToHubPeering 'modules/subscriptions/virtualDesktopSubscriptionVnetPeering.bicep' = {
  name: 'virtualDesktopToHubPeering'
  scope: subscription(virtualDesktopSubscriptionID)
  params: {
    remoteDesktopVnetRgName: virtualDesktopSubscription.outputs.rdVnetResourceGroupName
    remoteDesktopVnetName: virtualDesktopSubscription.outputs.rdVnetName
    hubVnetName: hubSubscription.outputs.hubVNETName
    hubVnetId: hubSubscription.outputs.hubVNETId
  }
}

module researcherToHubPeering 'modules/subscriptions/researcherSubscriptionVnetPeering.bicep' = {
  name: 'researcherToHubPeering'
  scope: subscription(researcherSubscriptionID)
  params: {
    researcherVnetRgName: researcherSubscription.outputs.researcherVnetResourceGroupName
    researcherVnetName: researcherSubscription.outputs.researcherVnetName
    hubVnetName: hubSubscription.outputs.hubVNETName
    hubVnetId: hubSubscription.outputs.hubVNETId
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('Resource ID of the Firewall.')
output firewallResourceID string = hubSubscription.outputs.firewallId

@description('Resource ID of the Bastion.')
output bastionResourceID string = virtualDesktopSubscription.outputs.bastionResourceId
@description('Resource ID of the hub virtual network.')
output hubVnetId string = hubSubscription.outputs.hubVNETId

@description('Resource ID of the spoke virtual network.')
output remoteDesktopVnetId string = virtualDesktopSubscription.outputs.rdVnetId

@description('Resource ID of the research virtual network.')
output researchVnetId string = researcherSubscription.outputs.researcherVnetId

@description('Resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = hubSubscription.outputs.logAnalyticsWorkspaceResourceId
