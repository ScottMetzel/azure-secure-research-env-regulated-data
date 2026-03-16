@description('Azure region for all network resources.')
param location string

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Tags to apply to all resources.')
param tags object

@description('Address prefix for the virtual network.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the compute subnet.')
param computeSubnetPrefix string = '10.0.2.0/24'

@description('Address prefix for the private endpoint subnet.')
param privateEndpointSubnetPrefix string = '10.0.3.0/24'

@description('Address prefix for the data integration subnet.')
param dataIntegrationSubnetPrefix string = '10.0.4.0/24'

@description('Address prefix of the hub Research subnet. Used in the compute NSG to allow inbound SSH only from researchers.')
param hubResearchSubnetPrefix string = '10.1.2.0/24'

// ── NSGs ──────────────────────────────────────────────────────────────────────

resource nsgCompute 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${environmentName}-compute-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-Hub-Research'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: hubResearchSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow SSH from the hub Research subnet (Bastion-connected jumpbox).'
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
          description: 'Block all outbound traffic to the internet from compute VMs.'
        }
      }
    ]
  }
}

resource nsgPrivateEndpoint 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${environmentName}-pe-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
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
          description: 'Block all inbound traffic from the internet to private endpoints.'
        }
      }
    ]
  }
}

resource nsgDataIntegration 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${environmentName}-di-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
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
          description: 'Block all inbound internet traffic to the data integration subnet.'
        }
      }
      {
        name: 'Allow-ADF-Outbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'DataFactory'
          destinationPortRange: '443'
          description: 'Allow ADF managed runtime outbound to Data Factory service tag.'
        }
      }
    ]
  }
}

// ── Virtual Network ───────────────────────────────────────────────────────────

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: '${environmentName}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: 'ComputeSubnet'
        properties: {
          addressPrefix: computeSubnetPrefix
          networkSecurityGroup: { id: nsgCompute.id }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'PrivateEndpointSubnet'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          networkSecurityGroup: { id: nsgPrivateEndpoint.id }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'DataIntegrationSubnet'
        properties: {
          addressPrefix: dataIntegrationSubnetPrefix
          networkSecurityGroup: { id: nsgDataIntegration.id }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: [
            { service: 'Microsoft.Storage' }
            { service: 'Microsoft.KeyVault' }
          ]
        }
      }
    ]
  }
}

// ── Private DNS Zones ─────────────────────────────────────────────────────────

// These zone names are mandated by Azure Private Link — they cannot be changed.
#disable-next-line no-hardcoded-env-urls
var blobPrivateLinkZone = 'privatelink.blob.core.windows.net'

var privateDnsZones = [
  blobPrivateLinkZone
  'privatelink.vaultcore.azure.net'
  'privatelink.datafactory.azure.net'
  'privatelink.azureml.ms'
]

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in privateDnsZones: {
  name: zone
  location: 'global'
  tags: tags
}]

resource dnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in privateDnsZones: {
  name: '${environmentName}-link'
  parent: dnsZones[i]
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}]

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the virtual network.')
output vnetId string = vnet.id

@description('The name of the virtual network.')
output vnetName string = vnet.name

@description('The resource ID of the compute subnet.')
output computeSubnetId string = vnet.properties.subnets[0].id

@description('The resource ID of the private endpoint subnet.')
output privateEndpointSubnetId string = vnet.properties.subnets[1].id

@description('The resource ID of the data integration subnet.')
output dataIntegrationSubnetId string = vnet.properties.subnets[2].id

@description('The resource IDs of the private DNS zones.')
output privateDnsZoneIds array = [for (zone, i) in privateDnsZones: dnsZones[i].id]

@description('The names of the private DNS zones (used to create additional VNet links).')
output privateDnsZoneNames array = privateDnsZones
