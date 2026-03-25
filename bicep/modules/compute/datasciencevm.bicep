@description('Azure region for the Data Science VMs.')
param location string = 'westus2'

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Dev'

@description('Resource ID of the subnet for VM NICs.')
param subnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-DSVM-01/subnets/Dev-Subnet-DSVM'

@description('Resource ID of the Log Analytics workspace. Used to associate Data Collection Rules (DCRs) with the Azure Monitor agent extension on each VM.')
#disable-next-line no-unused-params
param logAnalyticsWorkspaceId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/prod-rg-SOC-01/providers/microsoft.operationalinsights/workspaces/prod-law-soc-01'

@description('VM size for Data Science VMs.')
param vmSize string = 'Standard_D8s_v5'

@description('Number of Data Science VMs to create.')
@minValue(1)
@maxValue(20)
param vmCount int = 1

@description('Local administrator username.')
param adminUsername string = 'azureuser'

@description('Local administrator password.')
@secure()
param adminPassword string = ''

@description('Tags to apply to all resources.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}

// ── NICs (no public IP) ───────────────────────────────────────────────────────

resource dsVmNics 'Microsoft.Network/networkInterfaces@2023-05-01' = [
  for i in range(0, vmCount): {
    name: '${environmentName}-dsvm-nic-${i}'
    location: location
    tags: tags
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            privateIPAllocationMethod: 'Dynamic'
            subnet: { id: subnetId }
          }
        }
      ]
      enableAcceleratedNetworking: true
    }
  }
]

// ── Data Science VMs ──────────────────────────────────────────────────────────

resource dsVms 'Microsoft.Compute/virtualMachines@2023-07-01' = [
  for i in range(0, vmCount): {
    name: '${environmentName}-dsvm-${i}'
    location: location
    tags: tags
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      hardwareProfile: { vmSize: vmSize }
      osProfile: {
        computerName: 'dsvm-${i}'
        adminUsername: adminUsername
        adminPassword: adminPassword
        linuxConfiguration: {
          disablePasswordAuthentication: false
          patchSettings: {
            patchMode: 'AutomaticByPlatform'
            assessmentMode: 'AutomaticByPlatform'
          }
        }
      }
      storageProfile: {
        imageReference: {
          // Ubuntu 22.04 Data Science VM
          publisher: 'microsoft-dsvm'
          offer: 'ubuntu-2204'
          sku: '2204'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          managedDisk: { storageAccountType: 'Premium_LRS' }
          diskSizeGB: 128
          deleteOption: 'Delete'
        }
      }
      networkProfile: {
        networkInterfaces: [
          { id: dsVmNics[i].id, properties: { deleteOption: 'Delete' } }
        ]
      }
      diagnosticsProfile: {
        bootDiagnostics: { enabled: true }
      }
    }
    dependsOn: [dsVmNics[i]]
  }
]

// ── AAD Login Extension ───────────────────────────────────────────────────────

resource aadLoginExtensions 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [
  for i in range(0, vmCount): {
    name: 'AADSSHLoginForLinux'
    parent: dsVms[i]
    location: location
    properties: {
      publisher: 'Microsoft.Azure.ActiveDirectory'
      type: 'AADSSHLoginForLinux'
      typeHandlerVersion: '1.0'
      autoUpgradeMinorVersion: true
    }
  }
]

// ── Azure Monitor Agent Extension ─────────────────────────────────────────────

resource amaExtensions 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [
  for i in range(0, vmCount): {
    name: 'AzureMonitorLinuxAgent'
    parent: dsVms[i]
    location: location
    properties: {
      publisher: 'Microsoft.Azure.Monitor'
      type: 'AzureMonitorLinuxAgent'
      typeHandlerVersion: '1.0'
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: true
    }
    dependsOn: [aadLoginExtensions[i]]
  }
]

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('Array of resource IDs for the Data Science VMs.')
output vmIds array = [for i in range(0, vmCount): dsVms[i].id]

@description('Array of names for the Data Science VMs.')
output vmNames array = [for i in range(0, vmCount): dsVms[i].name]
