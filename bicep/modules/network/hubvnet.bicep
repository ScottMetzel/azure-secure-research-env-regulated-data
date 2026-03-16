@description('Azure region for all hub network resources.')
param location string

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Tags to apply to all resources.')
param tags object

@description('Address prefix for the hub virtual network.')
param hubVnetAddressPrefix string = '10.1.0.0/16'

@description('Address prefix for AzureFirewallSubnet (minimum /26).')
param firewallSubnetPrefix string = '10.1.0.0/26'

@description('Address prefix for AzureBastionSubnet (minimum /26).')
param bastionSubnetPrefix string = '10.1.1.0/26'

@description('Address prefix for the researcher access (jumpbox) subnet.')
param researchSubnetPrefix string = '10.1.2.0/24'

// ── NSG: AzureBastionSubnet ───────────────────────────────────────────────────
// Azure Bastion requires specific inbound/outbound rules.
// See: https://learn.microsoft.com/azure/bastion/bastion-nsg

resource nsgBastion 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${environmentName}-bastion-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      // ── Inbound ──────────────────────────────────────────────────────────────
      {
        name: 'Allow-HTTPS-Inbound-Internet'
        properties: {
          priority: 120
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow HTTPS from the internet (Bastion portal access).'
        }
      }
      {
        name: 'Allow-GatewayManager-Inbound'
        properties: {
          priority: 130
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow Azure Gateway Manager control plane traffic.'
        }
      }
      {
        name: 'Allow-AzureLoadBalancer-Inbound'
        properties: {
          priority: 140
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow Azure Load Balancer health probes.'
        }
      }
      {
        name: 'Allow-BastionHostCommunication-Inbound'
        properties: {
          priority: 150
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: ['8080', '5701']
          description: 'Allow Bastion host-to-host communication.'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic.'
        }
      }
      // ── Outbound ─────────────────────────────────────────────────────────────
      {
        name: 'Allow-RDP-SSH-Outbound-VNet'
        properties: {
          priority: 100
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: ['22', '3389']
          description: 'Allow RDP and SSH outbound to VNet targets.'
        }
      }
      {
        name: 'Allow-AzureCloud-HTTPS-Outbound'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
          description: 'Allow outbound HTTPS to Azure Cloud for Bastion control plane.'
        }
      }
      {
        name: 'Allow-BastionHostCommunication-Outbound'
        properties: {
          priority: 120
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: ['8080', '5701']
          description: 'Allow Bastion host-to-host outbound communication.'
        }
      }
      {
        name: 'Allow-GetSessionInfo-Outbound'
        properties: {
          priority: 130
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: ['80', '443']
          description: 'Allow session information retrieval (certificate validation, etc.).'
        }
      }
      {
        name: 'Deny-All-Outbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other outbound traffic from Bastion subnet.'
        }
      }
    ]
  }
}

// ── NSG: ResearchSubnet ───────────────────────────────────────────────────────

resource nsgResearch 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${environmentName}-research-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-From-Bastion'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: bastionSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          description: 'Allow RDP connections from Azure Bastion subnet only.'
        }
      }
      {
        name: 'Allow-SSH-From-Bastion'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: bastionSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow SSH connections from Azure Bastion subnet only.'
        }
      }
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 4000
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Block all inbound traffic from the internet.'
        }
      }
      {
        name: 'Deny-Internet-Outbound'
        properties: {
          priority: 4000
          protocol: '*'
          access: 'Deny'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '*'
          description: 'Prevent research VMs from reaching the internet directly.'
        }
      }
    ]
  }
}

// ── Hub Virtual Network ───────────────────────────────────────────────────────
// AzureFirewallSubnet and AzureBastionSubnet are reserved names required by Azure.

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: '${environmentName}-hub-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [hubVnetAddressPrefix]
    }
    subnets: [
      {
        // Azure Firewall requires this exact subnet name and a /26 minimum prefix.
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
          // NSGs are not supported on AzureFirewallSubnet.
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        // Azure Bastion requires this exact subnet name and a /26 minimum prefix.
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
          networkSecurityGroup: { id: nsgBastion.id }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'ResearchSubnet'
        properties: {
          addressPrefix: researchSubnetPrefix
          networkSecurityGroup: { id: nsgResearch.id }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the hub virtual network.')
output hubVnetId string = hubVnet.id

@description('The name of the hub virtual network.')
output hubVnetName string = hubVnet.name

@description('The resource ID of AzureFirewallSubnet.')
output firewallSubnetId string = hubVnet.properties.subnets[0].id

@description('The resource ID of AzureBastionSubnet.')
output bastionSubnetId string = hubVnet.properties.subnets[1].id

@description('The resource ID of ResearchSubnet (for the jumpbox VM NIC).')
output researchSubnetId string = hubVnet.properties.subnets[2].id
