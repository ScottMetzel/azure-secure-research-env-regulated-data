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

@description('Local administrator username for VMs.')
param adminUsername string = 'azureuser'

@description('Local administrator password for VMs.')
@secure()
param adminPassword string = ''

@description('Options: Bastion or AVD. Determines whether to deploy Azure Bastion with a virtual machine or Azure Virtual Desktop for remote access to the environment. Default is AVD.')
@allowed([
  'Bastion'
  'AVD'
])
param BastionOrAVD string = 'AVD'

@description('The Resource ID of the Log Analytics Workspace to link for monitoring. This should be the workspace deployed in the hub subscription.')
param logAnalyticsWorkspaceId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/prod-rg-SOC-01/providers/microsoft.operationalinsights/workspaces/prod-law-soc-01'

@description('The Subnet ID of the Bastion Subnet within the Remote Desktop VNET.')
param net_RemoteDesktop_bastionSubnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-RemoteDesktop-01/subnets/AzureBastionSubnet'

@description('The Subnet ID of the Remote Desktop Server Subnet within the Remote Desktop VNET.')
param net_RemoteDesktop_rdServerSubnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-RemoteDesktop-01/subnets/RDServerSubnet'

@description('The Subnet ID of the AVD Subnet within the Remote Desktop VNET.')
param net_RemoteDesktop_avdSubnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-RemoteDesktop-01/subnets/AVDSubnet'

@description('The date and time in UTC format. Used as part of the deployment name')
param deploymentTimestamp string = utcNow()

@description('Tags applied to every resource.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}

// ── Resource Groups ───────────────────────────────────────────────────────────
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

// ── Azure Bastion (bastion-rg; uses AzureBastionSubnet) ─────────
// Requirement: Bastion in a separate resource group from the hub VNet and VM.

module bastion '../bastion/bastion.bicep' = if (BastionOrAVD == 'Bastion') {
  name: 'bastion_${deploymentTimestamp}'
  scope: bastionRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    bastionSubnetId: net_RemoteDesktop_bastionSubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ── Remote Desktop VM ────────────
// Gen2 D4ds_v5 Windows Server 2025 Azure Edition VM — accessed via Azure Bastion.
// Requirement: VM in a separate resource group from both the hub VNet and Bastion.

module remoteDesktopVM '../compute/remoteDesktopVM.bicep' = if (BastionOrAVD == 'Bastion') {
  name: 'remoteDesktopVM_${deploymentTimestamp}'
  scope: rdServerVMRG
  params: {
    location: location
    environmentName: environmentName
    subnetId: net_RemoteDesktop_rdServerSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags: tags
  }
}

// ── AVD ────────────
module avd '../avd/avd.bicep' = if (BastionOrAVD == 'AVD') {
  name: 'avd_${deploymentTimestamp}'
  scope: avdRG
  params: {
    location: location
    environmentName: environmentName
    subnetId: net_RemoteDesktop_avdSubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags: tags
  }
}

// ── Outputs ───────────────────────────────────────────────────────────
@description('Azure Bastion Resource ID.')
output bastionResourceId string = ((BastionOrAVD == 'Bastion')
  ? bastion!.outputs.bastionId
  : 'Bastion deployment not selected, no Bastion resource created.')
