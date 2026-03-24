targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Prod'

@description('Local administrator username for VMs.')
param adminUsername string

@description('Local administrator password for VMs.')
@secure()
param adminPassword string

@description('Options: Bastion or AVD. Determines whether to deploy Azure Bastion with a virtual machine or Azure Virtual Desktop for remote access to the environment. Default is AVD.')
@allowed([
  'Bastion'
  'AVD'
])
param BastionOrAVD string = 'AVD'

@description('The Resource ID of the Log Analytics Workspace to link for monitoring. This should be the workspace deployed in the hub subscription.')
param logAnalyticsWorkspaceId string

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

@description('The private IP address of the Azure Firewall deployed in the hub, used as the next hop for forced tunneling from the Remote Desktop Server subnet.')
param azureFirewallPrivateIp string

@description('The string array of DNS servers to use on the Virtual Network.')
param vNETDNSServers array

@description('Tags applied to every resource.')
param tags object

// ── Resource Groups ───────────────────────────────────────────────────────────

@description('Spoke VNET resource group — contains the spoke Virtual Network (including Bastion subnet, Remote Desktop Server VM subnet, and AVD subnet for future AVD deployment)')
resource spokeVNETRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-NetworkInfrastructure-01'
  location: location
  tags: tags
}

@description('Bastion resource group — contains Azure Bastion and its public IP.')
resource bastionRG 'Microsoft.Resources/resourceGroups@2023-07-01' = if (BastionOrAVD == 'Bastion') {
  name: '${environmentName}-RG-Bastion-01'
  location: location
  tags: tags
}

@description('Remote Desktop Server VM resource group — contains the Remote Desktop Server VMs.')
resource rdServerVMRG 'Microsoft.Resources/resourceGroups@2023-07-01' = if (BastionOrAVD == 'Bastion') {
  name: '${environmentName}-RG-RDServerVM-01'
  location: location
  tags: tags
}

@description('AVD resource group — contains Azure Virtual Desktop resources.')
resource avdRG 'Microsoft.Resources/resourceGroups@2023-07-01' = if (BastionOrAVD == 'AVD') {
  name: '${environmentName}-RG-AVD-01'
  location: location
  tags: tags
}

// ── Resources ───────────────────────────────────────────────────────────
module networkingVirtualDesktop '../network/networking_virtualDesktop.bicep' = {
  name: 'virtualDesktopNetworking'
  scope: spokeVNETRG
  params: {
    location: location
    environmentName: environmentName
    BastionOrAVD: BastionOrAVD
    vnetAddressPrefix: vnetAddressPrefix
    bastionSubnetPrefix: bastionSubnetPrefix
    webSubnetPrefix: webSubnetPrefix
    appSubnetPrefix: appSubnetPrefix
    dbSubnetPrefix: dbSubnetPrefix
    storageSubnetPrefix: storageSubnetPrefix
    webVNETIntegrationSubnetPrefix: webVNETIntegrationSubnetPrefix
    rdServerSubnetPrefix: rdServerSubnetPrefix
    avdSubnetPrefix: avdSubnetPrefix
    vNETDNSServers: vNETDNSServers
    azureFirewallPrivateIp: azureFirewallPrivateIp
    tags: tags
  }
}

// ── Azure Bastion (bastion-rg; uses AzureBastionSubnet) ─────────
// Requirement: Bastion in a separate resource group from the hub VNet and VM.

module bastion '../bastion/bastion.bicep' = if (BastionOrAVD == 'Bastion') {
  name: 'bastion'
  scope: bastionRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    bastionSubnetId: networkingVirtualDesktop.outputs.AzureBastionSubnetId

    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ── Research VM ────────────
// Gen2 D4ds_v5 Windows Server 2025 Azure Edition VM — accessed via Azure Bastion.
// Requirement: VM in a separate resource group from both the hub VNet and Bastion.

module researchVm '../compute/researchvm.bicep' = if (BastionOrAVD == 'Bastion') {
  name: 'researchVm'
  scope: rdServerVMRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: networkingVirtualDesktop.outputs.RDServer01SubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// ── AVD ────────────
module avd '../avd/avd.bicep' = if (BastionOrAVD == 'AVD') {
  name: 'avd'
  scope: avdRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: networkingVirtualDesktop.outputs.AVD01SubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// ── Outputs ───────────────────────────────────────────────────────────
@description('The name of the Remote Desktop VNET Resource Group.')
output rdVnetResourceGroupName string = spokeVNETRG.name

@description('Remote Desktop VNET ID.')
output rdVnetId string = networkingVirtualDesktop.outputs.vnetId

@description('Remote Desktop VNET Name.')
output rdVnetName string = networkingVirtualDesktop.outputs.vnetName

@description('Azure Bastion Resource ID.')
output bastionResourceId string = bastion.outputs.bastionId
