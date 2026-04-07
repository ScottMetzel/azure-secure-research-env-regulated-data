@description('Azure region for AVD resources.')
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

@description('Resource ID of the subnet for session host NICs.')
param subnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-AVD-01/subnets/Dev-Subnet-AVD-SessionHosts'

@description('Resource ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/prod-rg-SOC-01/providers/microsoft.operationalinsights/workspaces/prod-law-soc-01'

@description('VM size for AVD session hosts.')
param vmSize string = 'Standard_D4s_v5'

@description('Number of session host VMs to create.')
@minValue(1)
@maxValue(50)
param vmCount int = 2

@description('Local administrator username for session host VMs.')
param adminUsername string = 'azureuser'

@description('Local administrator password for session host VMs.')
@secure()
param adminPassword string = ''

@description('Active Directory domain to join. Leave empty when using AAD join. Used to configure the domain join extension (not deployed when aadJoin is true).')
#disable-next-line no-unused-params
param domainToJoin string = ''

@description('Whether to join session hosts to Azure Active Directory (AAD).')
param aadJoin bool = true

@description('UTC timestamp used to set host pool registration token expiry. Must be a future time. Defaults to 8 hours from deployment time.')
param registrationTokenExpiry string = dateTimeAdd(utcNow(), 'PT8H')

@description('Tags to apply to all resources.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Prod'
}
// ── AVD Host Pool ─────────────────────────────────────────────────────────────

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: '${environmentName}-hp'
  location: location
  tags: tags
  properties: {
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    maxSessionLimit: 5
    preferredAppGroupType: 'Desktop'
    validationEnvironment: false
    registrationInfo: {
      expirationTime: registrationTokenExpiry
      registrationTokenOperation: 'Update'
    }
    startVMOnConnect: true
    // RDP security policy for the secure research environment:
    // - drivestoredirect:s:          → no local drives redirected (prevent data exfiltration)
    // - redirectclipboard:i:0        → clipboard redirection disabled (prevent copy/paste out)
    // - redirectprinters:i:0         → no printer redirection
    // - devicestoredirect:s:         → no device/USB redirection
    // - redirectcomports:i:0         → no COM port redirection
    // - redirectsmartcards:i:0       → no smart card redirection
    // - usbdevicestoredirect:s:      → no USB device redirection
    // - audiomode:i:0                → play audio locally (read-only, not record)
    // - videoplaybackmode:i:1        → video playback optimized
    // - enablecredsspsupport:i:1     → CredSSP NLA enabled (stronger authentication)
    customRdpProperty: 'drivestoredirect:s:;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:0;redirectprinters:i:0;devicestoredirect:s:;redirectcomports:i:0;redirectsmartcards:i:0;usbdevicestoredirect:s:;enablecredsspsupport:i:1;'
  }
}

// ── Application Group ─────────────────────────────────────────────────────────

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: '${environmentName}-dag'
  location: location
  tags: tags
  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPool.id
    friendlyName: 'Secure Research Desktop'
    description: 'Desktop application group for the Secure Research Environment.'
  }
}

// ── Workspace ─────────────────────────────────────────────────────────────────

resource avdWorkspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: '${environmentName}-ws'
  location: location
  tags: tags
  properties: {
    applicationGroupReferences: [appGroup.id]
    friendlyName: 'Secure Research Workspace'
    description: 'AVD workspace for the Secure Research Environment.'
  }
}

// ── Session Host VMs ──────────────────────────────────────────────────────────

var imageReference = aadJoin
  ? {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'windows-11'
      sku: 'win11-22h2-avd'
      version: 'latest'
    }
  : {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }

resource sessionHostNics 'Microsoft.Network/networkInterfaces@2023-05-01' = [
  for i in range(0, vmCount): {
    name: '${environmentName}-avd-nic-${i}'
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

resource sessionHostVMs 'Microsoft.Compute/virtualMachines@2023-07-01' = [
  for i in range(0, vmCount): {
    name: '${environmentName}-avd-vm-${i}'
    location: location
    tags: tags
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      hardwareProfile: { vmSize: vmSize }
      osProfile: {
        computerName: 'avd-vm-${i}'
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
        imageReference: imageReference
        osDisk: {
          createOption: 'FromImage'
          managedDisk: { storageAccountType: 'Premium_LRS' }
          deleteOption: 'Delete'
        }
      }
      networkProfile: {
        networkInterfaces: [
          { id: sessionHostNics[i].id, properties: { deleteOption: 'Delete' } }
        ]
      }
      diagnosticsProfile: {
        bootDiagnostics: { enabled: true }
      }
      licenseType: aadJoin ? 'Windows_Client' : 'Windows_Server'
    }
    dependsOn: [sessionHostNics[i]]
  }
]

// ── AAD Join Extension ────────────────────────────────────────────────────────

resource aadJoinExtensions 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [
  for i in range(0, vmCount): if (aadJoin) {
    name: 'AADLoginForWindows'
    parent: sessionHostVMs[i]
    location: location
    properties: {
      publisher: 'Microsoft.Azure.ActiveDirectory'
      type: 'AADLoginForWindows'
      typeHandlerVersion: '2.0'
      autoUpgradeMinorVersion: true
      settings: {
        mdmId: ''
      }
    }
  }
]

// ── AVD Agent Registration Extension ─────────────────────────────────────────

resource avdAgentExtensions 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [
  for i in range(0, vmCount): {
    name: 'Microsoft.PowerShell.DSC'
    parent: sessionHostVMs[i]
    location: location
    properties: {
      publisher: 'Microsoft.Powershell'
      type: 'DSC'
      typeHandlerVersion: '2.73'
      autoUpgradeMinorVersion: true
      settings: {
        #disable-next-line no-hardcoded-env-urls
        modulesUrl: 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip'
        configurationFunction: 'Configuration.ps1\\AddSessionHost'
        properties: {
          hostPoolName: hostPool.name
          registrationInfoTokenCredential: {
            UserName: 'PLACEHOLDER'
            Password: 'PrivateSettingsRef:registrationInfoToken'
          }
        }
      }
      protectedSettings: {
        Items: {
          registrationInfoToken: hostPool.properties.registrationInfo.token
        }
      }
    }
    dependsOn: aadJoin ? [aadJoinExtensions[i]] : []
  }
]

// ── Diagnostics ───────────────────────────────────────────────────────────────

resource hostPoolDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environmentName}-hp-diag'
  scope: hostPool
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the AVD host pool.')
output hostPoolId string = hostPool.id

@description('The resource ID of the AVD application group.')
output appGroupId string = appGroup.id

@description('The resource ID of the AVD workspace.')
output workspaceId string = avdWorkspace.id

@description('The name of the AVD host pool.')
output hostPoolName string = hostPool.name
