targetScope = 'resourceGroup'

// Define external IP address do GCP VPN gateway, criação de IP em GCP precisa ser rodado antes.
param gcp_vpn_gateway_ip string
param location string = 'eastus'



var virtualNetworkName = 'VNET01'
var subnetName = 'subnet01'
var gatewaySubnet = 'GatewaySubnet'
var networkInterfaceName = 'vm-nic'
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
var nsgName = 'vm-nsg'
var vpnIpPublicName = 'vpn-ipv4'
var ipPublicName = 'vm-ipv4'
var vmName = 'vm01'
var vpnGatewayName = 'vpn-gw'
var localNetworkGatewayName = 'localNetworkGateway'
var connectionName = 'vpnConnection'
var vmSize = 'Standard_B1ls'

// Define VNET e Subnet
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/25'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.10.0.0/27'
        }
      }
      {
        name: gatewaySubnet
        properties: {
          addressPrefix: '10.10.0.32/27'
        }
      }
    ]
  }
}

// Criar Ip Publico para VM
resource vpnPublicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: vpnIpPublicName
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Dynamic'
  }
}
resource publicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: ipPublicName
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Dynamic'
  }
}

// Define VPN Gateway do Tunnel em Azure
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2021-02-01' = {
  name: vpnGatewayName
  location: location
  dependsOn: [
    vpnPublicIP
    virtualNetwork
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${virtualNetwork.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: vpnPublicIP.id
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
    sku: {
      name: 'Basic'
      tier: 'Basic'
    }
  }
}

// Define o local network gateway para GCP network in Azure
resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2021-02-01' = {
  name: localNetworkGatewayName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: [
        '10.20.0.0/25'
      ]
    }
    gatewayIpAddress: '${gcp_vpn_gateway_ip}'
  }
}

// Define the connection between the VPN gateways in Azure and GCP
resource connection 'Microsoft.Network/connections@2021-02-01' = {
  name: connectionName
  location: location
  dependsOn: [
    localNetworkGateway
    vpnGateway
  ]
  properties: {
    virtualNetworkGateway1: {
      id: vpnGateway.id
    }
    localNetworkGateway2: {
      id: localNetworkGateway.id
    }
    connectionType: 'IPsec'
    routingWeight: 10
    sharedKey: 'shared-key-here'
    connectionProtocol: 'IKEv2'
  }
}

// Define NSG
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'ssh-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
      {
        name: 'icmp-allow'
        properties: {
          protocol: 'Icmp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 301
          direction: 'Inbound'
        }
      }
      {
        name: 'gcp-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '10.20.0.0/25'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 302
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Define NIC
resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: networkInterfaceName
  location: location
  dependsOn: [
    publicIP
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ip-config'
        properties: {
          subnet: {
            id: subnetRef
          }
          publicIPAddress: {
            id: publicIP.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// Create the VM in Azure
resource vm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: vmName
  location: location
  dependsOn: [
    nic
  ]
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'fromImage'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: 'ubuntu01'
      adminPassword: 'pwd-here'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

// Define Outputs
output vpnPublicIPName string = vpnPublicIP.name
