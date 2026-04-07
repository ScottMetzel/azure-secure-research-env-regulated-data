@description('Azure region for the Azure Firewall.')
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

@description('Resource ID of AzureFirewallSubnet (must be named exactly AzureFirewallSubnet).')
param firewallSubnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Hub-01/subnets/AzureFirewallSubnet'

@description('Number of days to retain Azure Firewall logs and metrics in the connected Log Analytics workspace.')
param PolicyAnalyticsRetentionInDays int = 90

@description('Resource ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/prod-rg-SOC-01/providers/microsoft.operationalinsights/workspaces/prod-law-soc-01'

@description('The DNS Servers to proxy to from the Azure Firewall DNS settings.')
param dnsServers array = [
  '168.63.129.16' // Example: IP address of an internal DNS forwarder or resolver in the hub VNet. This should be updated to the actual DNS server(s) used in the environment for name resolution.
]

@description('Address prefix for the Remote Desktop Server subnet.')
param net_RemoteDesktop_rdServerSubnetPrefix string = '10.100.41.0/24'

@description('Address prefix for the first Azure Virtual Desktop subnet.')
param net_RemoteDesktop_avdSubnetPrefix string = '10.100.42.0/24'

@description('Address prefix for the first Data Science Server subnet.')
param net_researcher_ServerSubnetPrefix string = '10.100.61.0/28'

@description('Azure DNS Private Resolver Inbound Endpoint Static Private IP Address. Must be within the address range of the AzDNSPRInbound01 subnet defined in the hub virtual network.')
param net_hub_azDNSPRInboundStaticIP string = '10.10.10.10'

@description('The private IP address of the Azure Firewall deployed in the hub, used as the next hop for forced tunneling from the Remote Desktop Server subnet.')
param net_hub_azureFirewallPrivateIP string = '10.100.0.4'

@description('The string array of FQDNs needed to allow Azure Machine Configuration to access Microsoft-managed Storage Accounts in Azure. These URLs are used in the Azure Firewall Policy and are region-specific. Default values are for West US 2. Refer to this article for more information:')
param azureMachineConfigStorageFQDNs array = [
  #disable-next-line no-hardcoded-env-urls
  'oaasguestconfigeuss1.blob.core.windows.net'
  #disable-next-line no-hardcoded-env-urls
  'oaasguestconfigeus2s1.blob.core.windows.net'
  #disable-next-line no-hardcoded-env-urls
  'oaasguestconfigwuss1.blob.core.windows.net'
  #disable-next-line no-hardcoded-env-urls
  'oaasguestconfigwus2s1.blob.core.windows.net'
  #disable-next-line no-hardcoded-env-urls
  'oaasguestconfigncuss1.blob.core.windows.net'
  #disable-next-line no-hardcoded-env-urls
  'oaasguestconfigcuss1.blob.core.windows.net'
  #disable-next-line no-hardcoded-env-urls
  'oaasguestconfigscuss1.blob.core.windows.net'
  #disable-next-line no-hardcoded-env-urls
  'oaasguestconfigwus3s1.blob.core.windows.net'
  #disable-next-line no-hardcoded-env-urls
  'oaasguestconfigwcuss1.blob.core.windows.net'
]

@description('Tags to apply to all resources.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}
// ── Variables ─────────────────────────────────────────────────────────────────
var azureMachineConfigFQDNs = concat(azureMachineConfigStorageFQDNs, ['*.guestconfiguration.azure.com'])

// ── Public IP ─────────────────────────────────────────────────────────────────
resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${environmentName}-PIP-AzureFirewall-01'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// ── IP Groups ───────────────────────────────────────────────────────────
resource ipgPrivateNetworks 'Microsoft.Network/ipGroups@2024-05-01' = {
  name: '${environmentName}-IPG-PrivateNetworks-01'
  location: location
  properties: {
    ipAddresses: [
      '10.0.0.0/8'
      '192.168.0.0/16'
      '172.16.0.0/12'
    ]
  }
}

resource ipgRemoteDesktop01 'Microsoft.Network/ipGroups@2024-05-01' = {
  name: '${environmentName}-IPG-RemoteDesktop-01'
  location: location
  properties: {
    ipAddresses: [
      net_RemoteDesktop_rdServerSubnetPrefix
      net_RemoteDesktop_avdSubnetPrefix
    ]
  }
}

resource ipgResearcherVM01 'Microsoft.Network/ipGroups@2024-05-01' = {
  name: '${environmentName}-IPG-ResearcherVM-01'
  location: location
  properties: {
    ipAddresses: [
      net_researcher_ServerSubnetPrefix
    ]
  }
}
// ── Firewall Policy ───────────────────────────────────────────────────────────

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: '${environmentName}-AFWP-Core-01'
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Premium'
    }
    threatIntelMode: 'Alert'
    dnsSettings: {
      enableProxy: true
      servers: dnsServers
    }
    insights: {
      isEnabled: true
      logAnalyticsResources: {
        defaultWorkspaceId: {
          id: logAnalyticsWorkspaceId
        }
      }
      retentionDays: PolicyAnalyticsRetentionInDays
    }
  }
}

// ── Firewall Policy Rule Collection Groups ─────────────────────────────────────
resource fwPolicyRCGGlobalAzurePlatform 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  name: 'Azure-Platform'
  parent: firewallPolicy
  properties: {
    priority: 1000
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'Azure-Platform_L4_Allow'
        priority: 500
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Azure-Global-Platform-IP_Allow'
            description: 'Allow outbound traffic to the Azure global platform IP address, used by various Azure services for operational needs.'
            sourceIpGroups: [
              ipgPrivateNetworks.id
            ]
            destinationAddresses: [
              '168.63.129.16'
            ]
            ipProtocols: [
              'TCP'
            ]
            destinationPorts: [
              '53'
              '80'
              '32526'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Azure-NTP_Allow'
            description: 'Allow outbound NTP traffic to time.windows.com.'
            sourceIpGroups: [
              ipgPrivateNetworks.id
            ]
            destinationFqdns: [
              'time.windows.com'
            ]
            ipProtocols: [
              'UDP'
            ]
            destinationPorts: [
              '123'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Azure-Global-Platform-FQDN_Allow'
            description: 'Allow outbound traffic to the Azure global platform FQDNs, used by various Azure services for operational needs.'
            sourceIpGroups: [
              ipgPrivateNetworks.id
            ]
            destinationFqdns: [
              #disable-next-line no-hardcoded-env-urls
              'azkms.core.windows.net'
              #disable-next-line no-hardcoded-env-urls
              'kms.core.windows.net'
            ]
            ipProtocols: [
              'TCP'
            ]
            destinationPorts: [
              '1688'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'Azure-Virtual-Desktop-Service_L4_Allow'
        priority: 501
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Azure-Virtual-Desktop-Service_Service-Tag-01_Allow'
            description: 'Allow outbound traffic to the Azure Virtual Desktop service endpoints, used by various Azure services for operational needs.'
            sourceIpGroups: [
              ipgRemoteDesktop01.id
            ]
            destinationAddresses: [
              'AzureActiveDirectory'
              'WindowsVirtualDesktop'
              'AzureFrontDoor.Frontend'
              'AzureMonitor'
            ]
            ipProtocols: [
              'TCP'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Azure-Virtual-Desktop-IP-01_Allow'
            description: 'Allow outbound traffic to the Azure FQDNs and wildcards for AVD services, used by various Azure services for operational needs.'
            sourceIpGroups: [
              ipgRemoteDesktop01.id
            ]
            destinationAddresses: [
              '169.254.169.254'
              '168.63.129.16'
            ]
            ipProtocols: [
              'TCP'
            ]
            destinationPorts: [
              '80'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Azure-Virtual-Desktop-FQDN-03_Allow'
            description: 'Allow outbound traffic to the Azure FQDNs and wildcards for AVD services, used by various Azure services for operational needs.'
            sourceIpGroups: [
              ipgRemoteDesktop01.id
            ]
            destinationFqdns: [
              #disable-next-line no-hardcoded-env-urls
              'azkms.core.windows.net'
            ]
            ipProtocols: [
              'TCP'
            ]
            destinationPorts: [
              '1688'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Azure-Virtual-Desktop-IP-02_Allow'
            description: 'Allow outbound traffic to the Azure IP Addresses for AVD services, used by various Azure services for operational needs.'
            sourceIpGroups: [
              ipgRemoteDesktop01.id
            ]
            destinationAddresses: [
              '51.5.0.0/16'
            ]
            ipProtocols: [
              'UDP'
            ]
            destinationPorts: [
              '3478'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'Azure-Virtual-Desktop-Service_L7_Allow'
        priority: 502
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'Azure-Virtual-Desktop-FQDN-01_Allow'
            description: 'Allow outbound traffic to the Azure FQDNs and wildcards for AVD services, used by various Azure services for operational needs.'
            sourceIpGroups: [
              ipgRemoteDesktop01.id
            ]
            targetFqdns: [
              'oneocsp.microsoft.com'
              'www.microsoft.com'
              '*.aikcertaia.microsoft.com'
              #disable-next-line no-hardcoded-env-urls
              'azcsprodeusaikpublish.blob.core.windows.net'
              '*.microsoftaik.azure.net'
              'ctldl.windowsupdate.com'
              'www.msftconnecttest.com'
              '*.digicert.com'
            ]
            protocols: [
              { protocolType: 'Http', port: 80 }
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'Azure-Virtual-Desktop-FQDN-02_Allow'
            description: 'Allow outbound traffic to the Azure FQDNs and wildcards for AVD services, used by various Azure services for operational needs.'
            sourceIpGroups: [
              ipgRemoteDesktop01.id
            ]
            targetFqdns: [
              #disable-next-line no-hardcoded-env-urls
              '*.prod.warm.ingest.monitor.core.windows.net'
              #disable-next-line no-hardcoded-env-urls
              'gcs.prod.monitoring.core.windows.net'
              #disable-next-line no-hardcoded-env-urls
              'mrsglobalsteus2prod.blob.core.windows.net'
              #disable-next-line no-hardcoded-env-urls
              'wvdportalstorageblob.blob.core.windows.net'
              'aka.ms'
              '*.windows.cloud.microsoft'
              '*.windows.static.microsoft'
              '*.events.data.microsoft.com'
              '*.prod.do.dsp.mp.microsoft.com'
              '*.sfx.ms'
              '*.azure-dns.com'
              '*.azure-dns.net'
              '*eh.servicebus.windows.net'
            ]
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'Azure-Platform_L7_Allow'
        priority: 503
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'Azure-Monitor_Allow'
            description: 'Allow outbound traffic to Azure Monitor endpoints for diagnostics and telemetry.'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            targetFqdns: [
              '*.ods.opinsights.azure.com'
              '*.oms.opinsights.azure.com'
              '*.monitoring.azure.com'
            ]
            sourceIpGroups: [
              ipgPrivateNetworks.id
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'Azure-Machine-Configuration_Allow'
            description: 'Allow outbound traffic to Azure Machine Configuration endpoints for diagnostics and telemetry.'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            targetFqdns: azureMachineConfigFQDNs
            sourceIpGroups: [
              ipgPrivateNetworks.id
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'Microsoft-Update_Allow'
            description: 'Allow Windows Update traffic for patch management.'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            targetFqdns: [
              '*.delivery.mp.microsoft.com'
              '*.download.windowsupdate.com'
              '*.update.microsoft.com'
              '*.windowsupdate.com'
            ]
            sourceIpGroups: [
              ipgPrivateNetworks.id
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'Microsoft-CRLs_Allow'
            description: 'Allow CRL Check traffic for certificate validation.'
            protocols: [
              { protocolType: 'Http', port: 80 }
            ]
            targetFqdns: [
              'www.microsoft.com'
              'ctldl.windowsupdate.com'
              'crl.microsoft.com'
              'packages.microsoft.com'
              'download.windowsupdate.com'
            ]
            sourceIpGroups: [
              ipgPrivateNetworks.id
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'Windows-Autopatch_Allow'
            description: 'Allow Windows Autopatch traffic for patch management.'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            targetFqdns: [
              '*.webpubsub.azure.com'
              'device.autopatch.microsoft.com'
              'devicelistenerprod.microsoft.com'
              'login.windows.net'
              'mmdcustomer.microsoft.com'
              'mmdls.microsoft.com'
              'services.autopatch.microsoft.com'
            ]
            sourceIpGroups: [
              ipgPrivateNetworks.id
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'Defender-for-Endpoint_Allow'
            description: 'Allow Microsoft Defender for Endpoint traffic for security management.'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            targetFqdns: [
              '*.delivery.mp.microsoft.com'
              '*.endpoint.security.microsoft.com'
              '*.security.microsoft.com'
              '*.smartscreen-prod.microsoft.com'
              '*.smartscreen.microsoft.com'
              '*.update.microsoft.com'
              '*.windowsupdate.com'
              'config.edge.skype.com'
              'download.microsoft.com'
              'download.windowsupdate.com'
              #disable-next-line no-hardcoded-env-urls
              'login.microsoftonline.com'
              'login.windows.net'
              'packages.microsoft.com'
              'www.microsoft.com'
            ]
            sourceIpGroups: [
              ipgPrivateNetworks.id
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'Entra-ID_Allow'
            description: 'Allow Microsoft Entra ID (Azure AD) authentication endpoints.'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            targetFqdns: [
              #disable-next-line no-hardcoded-env-urls
              'login.microsoftonline.com'
              'login.windows.net'
              #disable-next-line no-hardcoded-env-urls
              '*.login.microsoftonline.com'
              'go.microsoft.com'
            ]
            sourceIpGroups: [
              ipgPrivateNetworks.id
            ]
          }
        ]
      }
    ]
  }
}

resource fwPolicyRCGGlobalInternal 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  name: '${tags.WorkloadName}-Global_Internal'
  parent: firewallPolicy
  dependsOn: [
    fwPolicyRCGGlobalAzurePlatform
  ]
  properties: {
    priority: 1010
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'Internal-Services_L4_Allow'
        priority: 550
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'DNS_Allow'
            description: 'Allow DNS traffic to Azure Firewall and the Inbound Endpoint of the centrally-managed Azure DNS Private Resolver.'
            sourceIpGroups: [
              ipgPrivateNetworks.id
            ]
            destinationAddresses: [
              net_hub_azureFirewallPrivateIP
              net_hub_azDNSPRInboundStaticIP
            ]
            ipProtocols: [
              'TCP'
              'UDP'
            ]
            destinationPorts: ['53']
          }
        ]
      }
    ]
  }
}

resource fwPolicyRCGInternal 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  name: '${tags.WorkloadName}-Researcher_Internal-and-Internet'
  parent: firewallPolicy
  dependsOn: [
    fwPolicyRCGGlobalAzurePlatform
    fwPolicyRCGGlobalInternal
  ]
  properties: {
    priority: 1500
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'RemoteDesktop-to-ResearcherVM_L4_Allow'
        priority: 600
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'SSH-RDP_Allow'
            description: 'Allow SSH and RDP traffic from the Remote Desktop Spoke VNET to the Researcher VM Subnet in the Researcher Spoke VNET.'
            sourceIpGroups: [
              ipgRemoteDesktop01.id
            ]
            destinationIpGroups: [
              ipgResearcherVM01.id
            ]
            ipProtocols: [
              'TCP'
            ]
            destinationPorts: [
              '22'
              '3389'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'Researcher-VM-to-Internet_L7_Allow'
        priority: 601
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'Internet-HTTPS-01_Allow'
            description: 'Allow HTTPS traffic from the Researcher VM to the Internet.'
            sourceAddresses: [
              net_researcher_ServerSubnetPrefix
            ]
            targetFqdns: [
              'api.snapcraft.io'
              'archive.ubuntu.com'
              'azure.archive.ubuntu.com'
              'cloud.r-project.org'
              'developer.download.nvidia.com'
              'esm.ubuntu.com'
              'md-mqhk0tk55mfx.z30.blob.storage.azure.net'
              'motd.ubuntu.com'
              'nvidia.github.io'
              'packages.microsoft.com'
              'ppa.launchpadcontent.net'
              'repo.scala-sbt.org'
              'scala.jfrog.io'
              'security.ubuntu.com'
              #disable-next-line no-hardcoded-env-urls
              'umsar1tzn12qbbhwwgmw.blob.core.windows.net'
            ]
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'Internet-HTTP-01_Allow'
            description: 'Allow HTTP traffic from the Researcher VM to the Internet.'
            sourceAddresses: [
              net_researcher_ServerSubnetPrefix
            ]
            targetFqdns: [
              'azure.archive.ubuntu.com'
              'packages.microsoft.com'
            ]
            protocols: [
              { protocolType: 'Http', port: 80 }
            ]
          }
        ]
      }
    ]
  }
}

// ── Azure Firewall ────────────────────────────────────────────────────────────
resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: '${environmentName}-AFW-Core-01'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Premium'
    }
    firewallPolicy: { id: firewallPolicy.id }
    ipConfigurations: [
      {
        name: 'IPConfig01'
        properties: {
          publicIPAddress: { id: firewallPublicIp.id }
          subnet: { id: firewallSubnetId }
        }
      }
    ]
  }
  dependsOn: [
    fwPolicyRCGGlobalAzurePlatform
    fwPolicyRCGGlobalInternal
    fwPolicyRCGInternal
  ]
}

// ── Diagnostics ───────────────────────────────────────────────────────────────

resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'FirewallPolicySettings'
  scope: firewall
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    logAnalyticsDestinationType: 'Dedicated'
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the Azure Firewall.')
output firewallId string = firewall.id

@description('The name of the Azure Firewall.')
output firewallName string = firewall.name

@description('The private IP address of the Azure Firewall (used as the next-hop in UDRs).')
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress

@description('The public IP address of the Azure Firewall.')
output firewallPublicIpAddress string = firewallPublicIp.properties.ipAddress
