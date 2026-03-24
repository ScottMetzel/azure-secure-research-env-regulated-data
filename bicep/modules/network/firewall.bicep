@description('Azure region for the Azure Firewall.')
param location string

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Tags to apply to all resources.')
param tags object

@description('Resource ID of AzureFirewallSubnet (must be named exactly "AzureFirewallSubnet").')
param firewallSubnetId string

@description('Resource ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('The DNS Servers to proxy to from the Azure Firewall DNS settings.')
param dnsServers array

// ── Public IP ─────────────────────────────────────────────────────────────────

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
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

// ── Firewall Policy ───────────────────────────────────────────────────────────

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-05-01' = {
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
  }
}

// ── Firewall Policy Rule Collection Group ─────────────────────────────────────

resource ruleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-05-01' = {
  name: '${environmentName}-AFWP-RCG-01'
  parent: firewallPolicy
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'Allow-Azure-Services'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'Allow-AzureMonitor'
            description: 'Allow outbound traffic to Azure Monitor endpoints for diagnostics and telemetry.'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            targetFqdns: [
              '*.ods.opinsights.azure.com'
              '*.oms.opinsights.azure.com'
              '*.monitoring.azure.com'
            ]
            sourceAddresses: ['*']
          }
          {
            ruleType: 'ApplicationRule'
            name: 'Allow-MicrosoftUpdate'
            description: 'Allow Windows Update traffic for patch management.'
            protocols: [
              { protocolType: 'Https', port: 443 }
              { protocolType: 'Http', port: 80 }
            ]
            targetFqdns: [
              '*.update.microsoft.com'
              '*.windowsupdate.com'
              '*.download.windowsupdate.com'
              '*.delivery.mp.microsoft.com'
            ]
            sourceAddresses: ['*']
          }
          {
            ruleType: 'ApplicationRule'
            name: 'Allow-AzureActiveDirectory'
            description: 'Allow Microsoft Entra ID (Azure AD) authentication endpoints.'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            targetFqdns: [
              // These FQDNs are Microsoft-defined global endpoints for Entra ID authentication.
              // They are stable, well-known addresses (not environment-specific) that are
              // required for AAD-joined VMs, Managed Identity token acquisition, and Azure CLI
              // sign-in to function correctly inside the isolated network.
              #disable-next-line no-hardcoded-env-urls
              'login.microsoftonline.com'
              'login.windows.net'
              #disable-next-line no-hardcoded-env-urls
              '*.login.microsoftonline.com'
            ]
            sourceAddresses: ['*']
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'Deny-Internet-Egress'
        priority: 65000
        action: {
          type: 'Deny'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Deny-All-Outbound-Internet'
            description: 'Deny all outbound internet traffic not explicitly allowed by higher-priority rules.'
            ipProtocols: ['Any']
            sourceAddresses: ['*']
            destinationAddresses: ['*']
            destinationPorts: ['*']
          }
        ]
      }
    ]
  }
}

// ── Azure Firewall ────────────────────────────────────────────────────────────

resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
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
  dependsOn: [ruleCollectionGroup]
}

// ── Diagnostics ───────────────────────────────────────────────────────────────

resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environmentName}-fw-diag'
  scope: firewall
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

@description('The resource ID of the Azure Firewall.')
output firewallId string = firewall.id

@description('The name of the Azure Firewall.')
output firewallName string = firewall.name

@description('The private IP address of the Azure Firewall (used as the next-hop in UDRs).')
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress

@description('The public IP address of the Azure Firewall.')
output firewallPublicIpAddress string = firewallPublicIp.properties.ipAddress
