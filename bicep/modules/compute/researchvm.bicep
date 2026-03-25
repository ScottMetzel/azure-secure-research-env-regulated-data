@description('Azure region for the research VM.')
param location string = 'westus2'

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Dev'

@description('Resource ID of the subnet for the VM NIC (ResearchSubnet in the hub VNet).')
param subnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Hub-01/subnets/Dev-Subnet-Research'

@description('Resource ID of the Log Analytics workspace. Used to associate the Azure Monitor Agent extension.')
param logAnalyticsWorkspaceId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/prod-rg-SOC-01/providers/microsoft.operationalinsights/workspaces/prod-law-soc-01'

@description('VM size. Must be a Generation 2-capable, General Purpose size.')
param vmSize string = 'Standard_D4ds_v5'

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

// ── NIC (no public IP) ────────────────────────────────────────────────────────

resource researchVmNic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: '${environmentName}-research-nic'
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

// ── Research VM ───────────────────────────────────────────────────────────────
// Generation 2 VM running Windows Server 2025 Azure Edition.
// Access is via Azure Bastion only — no public IP is attached.

resource researchVm 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: '${environmentName}-research-vm'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'research-vm'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          assessmentMode: 'AutomaticByPlatform'
        }
      }
    }
    storageProfile: {
      imageReference: {
        // Windows Server 2025 Azure Edition — supports Generation 2 and Trusted Launch.
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        { id: researchVmNic.id, properties: { deleteOption: 'Delete' } }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: { enabled: true }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    licenseType: 'Windows_Server'
  }
}

// ── AAD Login Extension ───────────────────────────────────────────────────────

resource aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2015-06-15' = {
  name: 'AADLoginForWindows'
  parent: researchVm
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

// ── Azure Monitor Agent Extension ─────────────────────────────────────────────

resource amaExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  name: 'AzureMonitorWindowsAgent'
  parent: researchVm
  location: location
  dependsOn: [aadLoginExtension]
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the research VM.')
output vmId string = researchVm.id

@description('The name of the research VM.')
output vmName string = researchVm.name

@description('The Log Analytics workspace resource ID (echo for caller convenience).')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspaceId
