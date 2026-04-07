@description('Azure region for the research VM.')
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

@description('Resource ID of the subnet for the VM NIC (Remote Desktop Subnet in the Remote Desktop VNET).')
param subnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-RemoteDesktop-01/subnets/Dev-Subnet-RemoteDesktop'

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

// ── Variables ───────────────────────────────────────────────────────────────
var serverNameBase = 'RDVM'
var serverNameVM = '${serverNameBase}01'
var serverOSDiskName = '${environmentName}-MDK-${serverNameVM}-01'
var serverNICName = '${environmentName}-NIC-${serverNameVM}-01'

// ── NIC (no public IP) ────────────────────────────────────────────────────────

resource remoteDesktopVMNIC 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: serverNICName
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

// ── Remote Desktop VM ───────────────────────────────────────────────────────────────
// Generation 2 VM running Windows Server 2025 Azure Edition.
// Access is via Azure Bastion only — no public IP is attached.

resource remoteDesktopVM 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: serverNameVM
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
      computerName: serverNameVM
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
        name: serverOSDiskName
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: remoteDesktopVMNIC.id
          properties: {
            deleteOption: 'Delete'
          }
        }
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
  parent: remoteDesktopVM
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
  parent: remoteDesktopVM
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

@description('The resource ID of the Remote Desktop VM.')
output vmId string = remoteDesktopVM.id

@description('The name of the Remote Desktop VM.')
output vmName string = remoteDesktopVM.name
