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

@description('The Resource ID of the Researcher Spoke Virtual Network.')
param net_researcher_vnetId string = ''

@description('The resource ID of the App01 subnet.')
param net_researcher_App01SubnetId string = ''

@description('The resource ID of the Storage01 subnet.')
param net_researcher_Storage01SubnetId string = ''

@description('The resource ID of the Key Vault 01 subnet.')
param net_researcher_KeyVault01SubnetId string = ''

@description('The resource ID of the ResearcherVMSubnet01 subnet.')
param net_researcher_ResearcherVMSubnet01SubnetId string = ''

@description('Local administrator username for VMs.')
param adminUsername string = 'azureuser'

@description('Local administrator password for VMs.')
@secure()
param adminPassword string = ''

@description('VM size for Data Science VMs.')
param researcherVMSize string = 'Standard_D8s_v5'

@description('Number of Data Science VMs.')
@minValue(1)
@maxValue(1)
param researcherVMCount int = 1

@description('The email address of the data approver, who will receive notifications and approval requests when researchers attempt to upload data to the secure environment.')
param dataApproverEmail string = 'data.approver@example.com'

@description('The Resource ID of the Log Analytics Workspace to link for monitoring. This should be the workspace deployed in the hub subscription.')
param logAnalyticsWorkspaceId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/prod-rg-SOC-01/providers/microsoft.operationalinsights/workspaces/prod-law-soc-01'

@description('Resource ID of the Azure Blob Storage Private DNS Zone.')
#disable-next-line no-hardcoded-env-urls
param blobStoragePrivateDnsZoneId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'

@description('Resource ID of the Key Vault Private DNS Zone.')
param keyVaultPrivateDnsZoneId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'

@description('Resource ID of the Data Factory Private DNS Zone.')
param dataFactoryPrivateDnsZoneId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/privateDnsZones/privatelink.datafactory.azure.net'

@description('Resource ID of the Azure ML Private DNS Zone.')
param azureMLPrivateDnsZoneId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/privateDnsZones/privatelink.azureml.ms'

@description('The date and time in UTC format. Used as part of the deployment name')
param deploymentTimestamp string = utcNow()

@description('Tags applied to every resource.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}

// ── Resource Groups ───────────────────────────────────────────────────────────
@description('Data owner/approver resource group — contains the publicly-accessible data ingestion storage account, Logic App, and Fabric Data Factory resources.')
resource dataOwnerApproverRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-DataOwnerApprover-01'
  location: location
  tags: tags
}

@description('Researcher resource group — contains the resources which researchers will be primarily working with.')
resource researcherRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-Researcher-01'
  location: location
  tags: tags
}

// ── Resources via Modules ───────────────────────────────────────────────────────────

// ── Key Vault (compute-rg, private endpoint in PrivateEndpointSubnet) ─────────

module keyvault '../keyvault/keyvault.bicep' = {
  name: 'keyvault_${deploymentTimestamp}'
  scope: researcherRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: net_researcher_KeyVault01SubnetId
    vnetId: net_researcher_vnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    keyVaultPrivateDnsZoneId: keyVaultPrivateDnsZoneId // The first zone in the array is the Key Vault zone.
  }
}

// ── Ingestion Storage (ingest-rg) ─────────────────────────────────────────────
// Publicly-accessible storage for external data uploads.
// Requirement: Public storage account in its own resource group.

module storageIngestion '../storage/storageIngestion.bicep' = {
  name: 'storageIngestion_${deploymentTimestamp}'
  scope: dataOwnerApproverRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ── Secure Storage (compute-rg, private endpoint in PrivateEndpointSubnet) ────

module storageSecure '../storage/storageSecure.bicep' = {
  name: 'storageSecure_${deploymentTimestamp}'
  scope: researcherRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: net_researcher_Storage01SubnetId
    vnetId: net_researcher_vnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    keyVaultId: keyvault.outputs.keyVaultId
    blobStoragePrivateDnsZoneId: blobStoragePrivateDnsZoneId
  }
}

// ── Data Factory (compute-rg, private endpoint in DataIntegrationSubnet) ──────

module datafactory '../datafactory/datafactory.bicep' = {
  name: 'datafactory_${deploymentTimestamp}'
  scope: researcherRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: net_researcher_App01SubnetId
    vnetId: net_researcher_vnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    secureStorageAccountId: storageSecure.outputs.storageAccountId
    secureStorageAccountName: storageSecure.outputs.storageAccountName
    keyVaultId: keyvault.outputs.keyVaultId
    dataFactoryPrivateDnsZoneId: dataFactoryPrivateDnsZoneId
  }
}

// ── ADF → Ingestion Storage Role Assignment (ingest-rg) ──────────────────────
// The ingestion storage account lives in ingest-rg while ADF lives in compute-rg.
// The role assignment must be deployed in ingest-rg to avoid a cross-RG scope error.

module adfIngestionRoleAssignment '../roleAssignment/roleAssignment.bicep' = {
  name: 'adfIngestionRoleAssignment_${deploymentTimestamp}'
  scope: dataOwnerApproverRG
  params: {
    principalId: datafactory.outputs.dataFactoryPrincipalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    seed: '${storageIngestion.outputs.storageAccountId}-adf-sbc'
  }
}

// ── Data Science VMs (compute-rg, NICs in ComputeSubnet) ─────────────────────

module datasciencevm '../compute/datasciencevm.bicep' = {
  name: 'datasciencevm_${deploymentTimestamp}'
  scope: researcherRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: net_researcher_ResearcherVMSubnet01SubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    vmSize: researcherVMSize
    vmCount: researcherVMCount
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// ── Egress Approval Logic App (logicapp-rg) ───────────────────────────────────
// Requirement: Logic App in its own resource group.

module egressApproval '../logicapp/egressApproval.bicep' = {
  name: 'egressApproval_${deploymentTimestamp}'
  scope: dataOwnerApproverRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    approverEmail: dataApproverEmail
    secureStorageAccountId: storageSecure.outputs.storageAccountId
    secureStorageAccountName: storageSecure.outputs.storageAccountName
    keyVaultId: keyvault.outputs.keyVaultId
  }
}

// ── Outputs ───────────────────────────────────────────────────────────
