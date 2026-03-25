@description('Azure region for Azure Bastion.')
param location string = 'westus2'

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Dev'

@description('Resource ID of AzureBastionSubnet (must be named exactly "AzureBastionSubnet").')
param bastionSubnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Bastion-01/subnets/AzureBastionSubnet'

@description('Resource ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/prod-rg-SOC-01/providers/microsoft.operationalinsights/workspaces/prod-law-soc-01'

@description('Tags to apply to all resources.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}

// ── Public IP ─────────────────────────────────────────────────────────────────

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${environmentName}-bastion-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// ── Azure Bastion ─────────────────────────────────────────────────────────────
// Standard SKU enables file transfer, IP-based connection, and tunneling,
// which are required for a secure research jumpbox scenario.

resource bastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: '${environmentName}-bastion'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: { id: bastionPublicIp.id }
          subnet: { id: bastionSubnetId }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    // Standard SKU features for a secure research environment:
    enableFileCopy: true
    enableIpConnect: true
    enableShareableLink: false
    enableTunneling: true
    scaleUnits: 2
    // Copy-paste is intentionally disabled to prevent data exfiltration via the clipboard.
    // Researchers connect to VMs that hold regulated data; allowing clipboard transfer would
    // bypass the data-egress approval workflow enforced by the Logic App.
    disableCopyPaste: true
  }
}

// ── Diagnostics ───────────────────────────────────────────────────────────────

resource bastionDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environmentName}-bastion-diag'
  scope: bastion
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the Azure Bastion host.')
output bastionId string = bastion.id

@description('The name of the Azure Bastion host.')
output bastionName string = bastion.name

@description('The public IP address of Azure Bastion.')
output bastionPublicIpAddress string = bastionPublicIp.properties.ipAddress
