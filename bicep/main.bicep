targetScope = 'subscription'

// ── Parameters ────────────────────────────────────────────────────────────────

@description('Azure region for all resources.')
param location string = 'eastus'

@description('Short environment name used as a prefix for all resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'sre'

@description('Tags applied to every resource.')
param tags object = {
  environment: 'secure-research'
  managedBy: 'bicep'
}

@description('Local administrator username for VMs.')
param adminUsername string

@description('Local administrator password for VMs.')
@secure()
param adminPassword string

@description('Email address to receive data-egress approval requests.')
param approverEmail string

@description('Address prefix for the spoke virtual network.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the hub virtual network (must not overlap with spoke).')
param hubVnetAddressPrefix string = '10.1.0.0/16'

@description('VM size for Data Science VMs.')
param dsVmSize string = 'Standard_D8s_v5'

@description('Number of Data Science VMs.')
@minValue(1)
@maxValue(20)
param dsVmCount int = 1

// ── Resource Groups ───────────────────────────────────────────────────────────

@description('Monitoring resource group — contains the Log Analytics workspace.')
resource monitoringRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-monitoring-rg'
  location: location
  tags: tags
}

@description('Hub VNet resource group — contains the hub virtual network (Firewall, Bastion, Research subnets). Satisfies requirement: VNet in its own resource group.')
resource hubVnetRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-hubvnet-rg'
  location: location
  tags: tags
}

@description('Firewall resource group — contains Azure Firewall and its policy. Satisfies requirement: Firewall components in a separate resource group from the VNet.')
resource firewallRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-firewall-rg'
  location: location
  tags: tags
}

@description('Bastion resource group — contains Azure Bastion and its public IP. Satisfies requirement: Bastion in a separate resource group from the VNet and the VM.')
resource bastionRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-bastion-rg'
  location: location
  tags: tags
}

@description('Research VM resource group — contains the Gen2 Windows Server 2025 Azure Edition jumpbox VM. Satisfies requirement: VM in its own resource group.')
resource researchVmRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-researchvm-rg'
  location: location
  tags: tags
}

@description('Spoke network resource group — contains the spoke VNet and private DNS zones.')
resource networkRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-network-rg'
  location: location
  tags: tags
}

@description('Compute resource group — contains Key Vault, secure storage, Data Factory, and Data Science VMs.')
resource computeRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-compute-rg'
  location: location
  tags: tags
}

@description('Ingestion resource group — contains the publicly-accessible data ingestion storage account. Satisfies requirement: public storage in its own resource group.')
resource ingestRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-ingest-rg'
  location: location
  tags: tags
}

@description('Logic App resource group — contains the data-egress approval Logic App. Satisfies requirement: Logic App in its own resource group.')
resource logicAppRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-logicapp-rg'
  location: location
  tags: tags
}

// ── Monitoring (monitoring-rg) ────────────────────────────────────────────────

module monitoring 'modules/monitoring/logAnalytics.bicep' = {
  name: 'monitoring'
  scope: monitoringRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
  }
}

// ── Spoke VNet (network-rg) ───────────────────────────────────────────────────
// Contains ComputeSubnet, PrivateEndpointSubnet, DataIntegrationSubnet
// and all private DNS zones for private endpoints.

module network 'modules/network/vnet.bicep' = {
  name: 'network'
  scope: networkRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    vnetAddressPrefix: vnetAddressPrefix
  }
}

// ── Hub VNet (hubvnet-rg) ─────────────────────────────────────────────────────
// Contains AzureFirewallSubnet, AzureBastionSubnet, ResearchSubnet.
// Requirement: VNet hosting Firewall is in its own resource group (hubvnet-rg);
// Firewall, Bastion, and research VM are each deployed in separate resource groups.

module hubVnet 'modules/network/hubvnet.bicep' = {
  name: 'hubVnet'
  scope: hubVnetRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    hubVnetAddressPrefix: hubVnetAddressPrefix
  }
}

// ── VNet Peerings ─────────────────────────────────────────────────────────────
// Peerings are deployed as separate modules to avoid a circular dependency
// between the hub and spoke VNet modules.

module hubToSpokePeering 'modules/network/vnetPeering.bicep' = {
  name: 'hubToSpokePeering'
  scope: hubVnetRg
  params: {
    localVnetName: hubVnet.outputs.hubVnetName
    remoteVnetId: network.outputs.vnetId
    peeringSuffix: 'to-spoke'
  }
}

module spokeToHubPeering 'modules/network/vnetPeering.bicep' = {
  name: 'spokeToHubPeering'
  scope: networkRg
  params: {
    localVnetName: network.outputs.vnetName
    remoteVnetId: hubVnet.outputs.hubVnetId
    peeringSuffix: 'to-hub'
  }
}

// ── Hub VNet DNS Zone Links (network-rg, where DNS zones live) ────────────────
// Creates additional VNet links so the research VM in the hub can resolve
// private endpoint DNS names (storage, Key Vault, ADF, etc.).

module hubDnsZoneLinks 'modules/network/dnsZoneLinks.bicep' = {
  name: 'hubDnsZoneLinks'
  scope: networkRg
  params: {
    environmentName: environmentName
    tags: tags
    vnetId: hubVnet.outputs.hubVnetId
    dnsZoneNames: network.outputs.privateDnsZoneNames
  }
}

// ── Azure Firewall (firewall-rg; uses AzureFirewallSubnet from hub VNet) ──────
// Requirement: Firewall components in a separate resource group from the hub VNet.

module firewall 'modules/network/firewall.bicep' = {
  name: 'firewall'
  scope: firewallRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    firewallSubnetId: hubVnet.outputs.firewallSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
  }
}

// ── Azure Bastion (bastion-rg; uses AzureBastionSubnet from hub VNet) ─────────
// Requirement: Bastion in a separate resource group from the hub VNet and VM.

module bastion 'modules/bastion/bastion.bicep' = {
  name: 'bastion'
  scope: bastionRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    bastionSubnetId: hubVnet.outputs.bastionSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
  }
}

// ── Research VM (researchvm-rg; NIC in ResearchSubnet of hub VNet) ────────────
// Gen2 D4ds_v5 Windows Server 2025 Azure Edition VM — accessed via Azure Bastion.
// Requirement: VM in a separate resource group from both the hub VNet and Bastion.

module researchVm 'modules/compute/researchvm.bicep' = {
  name: 'researchVm'
  scope: researchVmRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: hubVnet.outputs.researchSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// ── Key Vault (compute-rg, private endpoint in PrivateEndpointSubnet) ─────────

module keyvault 'modules/keyvault/keyvault.bicep' = {
  name: 'keyvault'
  scope: computeRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: network.outputs.privateEndpointSubnetId
    vnetId: network.outputs.vnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
  }
}

// ── Ingestion Storage (ingest-rg) ─────────────────────────────────────────────
// Publicly-accessible storage for external data uploads.
// Requirement: Public storage account in its own resource group.

module storageIngestion 'modules/storage/storageIngestion.bicep' = {
  name: 'storageIngestion'
  scope: ingestRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
  }
}

// ── Secure Storage (compute-rg, private endpoint in PrivateEndpointSubnet) ────

module storageSecure 'modules/storage/storageSecure.bicep' = {
  name: 'storageSecure'
  scope: computeRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: network.outputs.privateEndpointSubnetId
    vnetId: network.outputs.vnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
    keyVaultId: keyvault.outputs.keyVaultId
  }
}

// ── Data Factory (compute-rg, private endpoint in DataIntegrationSubnet) ──────

module datafactory 'modules/datafactory/datafactory.bicep' = {
  name: 'datafactory'
  scope: computeRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: network.outputs.dataIntegrationSubnetId
    vnetId: network.outputs.vnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
    secureStorageAccountId: storageSecure.outputs.storageAccountId
    secureStorageAccountName: storageSecure.outputs.storageAccountName
    keyVaultId: keyvault.outputs.keyVaultId
  }
}

// ── ADF → Ingestion Storage Role Assignment (ingest-rg) ──────────────────────
// The ingestion storage account lives in ingest-rg while ADF lives in compute-rg.
// The role assignment must be deployed in ingest-rg to avoid a cross-RG scope error.

module adfIngestionRoleAssignment 'modules/roleAssignment/roleAssignment.bicep' = {
  name: 'adfIngestionRoleAssignment'
  scope: ingestRg
  params: {
    principalId: datafactory.outputs.dataFactoryPrincipalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    seed: '${storageIngestion.outputs.storageAccountId}-adf-sbc'
  }
}

// ── Data Science VMs (compute-rg, NICs in ComputeSubnet) ─────────────────────

module datasciencevm 'modules/compute/datasciencevm.bicep' = {
  name: 'datasciencevm'
  scope: computeRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: network.outputs.computeSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
    vmSize: dsVmSize
    vmCount: dsVmCount
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// ── Egress Approval Logic App (logicapp-rg) ───────────────────────────────────
// Requirement: Logic App in its own resource group.

module egressApproval 'modules/logicapp/egressApproval.bicep' = {
  name: 'egressApproval'
  scope: logicAppRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
    approverEmail: approverEmail
    secureStorageAccountId: storageSecure.outputs.storageAccountId
    secureStorageAccountName: storageSecure.outputs.storageAccountName
    keyVaultId: keyvault.outputs.keyVaultId
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('Name of the monitoring resource group.')
output monitoringResourceGroupName string = monitoringRg.name

@description('Name of the hub VNet resource group (contains the hub VNet with Firewall, Bastion, and Research subnets).')
output hubVnetResourceGroupName string = hubVnetRg.name

@description('Name of the Firewall resource group.')
output firewallResourceGroupName string = firewallRg.name

@description('Name of the Bastion resource group.')
output bastionResourceGroupName string = bastionRg.name

@description('Name of the research VM resource group.')
output researchVmResourceGroupName string = researchVmRg.name

@description('Name of the spoke network resource group.')
output networkResourceGroupName string = networkRg.name

@description('Name of the compute resource group.')
output computeResourceGroupName string = computeRg.name

@description('Name of the ingestion resource group.')
output ingestResourceGroupName string = ingestRg.name

@description('Name of the Logic App resource group.')
output logicAppResourceGroupName string = logicAppRg.name

@description('Resource ID of the hub virtual network.')
output hubVnetId string = hubVnet.outputs.hubVnetId

@description('Resource ID of the spoke virtual network.')
output spokeVnetId string = network.outputs.vnetId

@description('Resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceResourceId

@description('Resource ID of the Key Vault.')
output keyVaultId string = keyvault.outputs.keyVaultId

@description('URI of the Key Vault.')
output keyVaultUri string = keyvault.outputs.keyVaultUri

@description('Name of the ingestion storage account.')
output ingestionStorageAccountName string = storageIngestion.outputs.storageAccountName

@description('Name of the secure storage account.')
output secureStorageAccountName string = storageSecure.outputs.storageAccountName

@description('Name of the Azure Data Factory.')
output dataFactoryName string = datafactory.outputs.dataFactoryName

@description('Name of the research VM.')
output researchVmName string = researchVm.outputs.vmName

@description('Name of the Azure Bastion host.')
output bastionName string = bastion.outputs.bastionName

@description('Name of the Azure Firewall.')
output firewallName string = firewall.outputs.firewallName

@description('HTTP callback URL for the egress approval Logic App.')
output egressApprovalCallbackUrl string = egressApproval.outputs.logicAppCallbackUrl
