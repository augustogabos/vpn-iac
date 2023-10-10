# gcp vpn-ipv4 created before running code
data "google_compute_address" "vpn_static_ip" {
  name = "vpn-ipv4"
}

# Define the resource that will contain the VPN gateway
resource "google_compute_network" "vpc_network" {
  name = "vpc01-network"
  auto_create_subnetworks = false
}

# Define the subnet for the VPN gateway
resource "google_compute_subnetwork" "vpc_subnet" {
  name          = "subnet01"
  ip_cidr_range = "10.20.0.0/27"
  network       = google_compute_network.vpc_network.self_link
  region        = var.region
}

# Create the firewall rules to allow inbound traffic from Azure
resource "google_compute_firewall" "azure_traffic" {
  name = "allow-azure"
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.10.0.0/25"]
}

resource "google_compute_firewall" "ssh_traffic" {
  name = "allow-ssh"
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_vpn_gateway" "target_gateway" {
  name    = "vpn-1"
  network = google_compute_network.vpc_network.self_link
}

resource "google_compute_vpn_tunnel" "tunnel1" {
  name          = "tunnel-1"
  peer_ip       = var.azure_vpn_gateway_ip //vpn-gw ip >> vpn-ipv4
  shared_secret = var.gw_shared_key

  target_vpn_gateway = google_compute_vpn_gateway.target_gateway.self_link

  local_traffic_selector  = ["10.20.0.0/27"]
  remote_traffic_selector = ["10.10.0.0/25"]
  
  depends_on = [
    google_compute_forwarding_rule.fr_esp,
    google_compute_forwarding_rule.fr_udp500,
    google_compute_forwarding_rule.fr_udp4500,
  ]
}

resource "google_compute_forwarding_rule" "fr_esp" {
  name        = "fr-esp"
  ip_protocol = "ESP"
  ip_address  = data.google_compute_address.vpn_static_ip.address
  target      = google_compute_vpn_gateway.target_gateway.self_link
}

resource "google_compute_forwarding_rule" "fr_udp500" {
  name        = "fr-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = data.google_compute_address.vpn_static_ip.address
  target      = google_compute_vpn_gateway.target_gateway.self_link
}

resource "google_compute_forwarding_rule" "fr_udp4500" {
  name        = "fr-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = data.google_compute_address.vpn_static_ip.address
  target      = google_compute_vpn_gateway.target_gateway.self_link
}

resource "google_compute_route" "route1" {
  name              = "route1"
  network           = google_compute_network.vpc_network.self_link
  dest_range        = var.azure_local_network_cidr
  priority          = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel1.self_link
}

# Define the VM instance to ping the Azure virtual network
resource "google_compute_instance" "vm_instance" {
  name              = "vm01"
  machine_type      = "e2-micro"
  zone              = var.zone
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  metadata_startup_script = "echo '${var.useradmin}:${var.userpwd}' | sudo chpasswd"

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet.self_link
    access_config {
      # One IP was generated automatically on the subnet
    }
  }
}