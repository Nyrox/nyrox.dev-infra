
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      # Here we use version 1.56.0, this may change in the future
      version = "1.56.0"
    }
  }
}

variable "network_id" {
  type        = number
  description = "Hetzner Network ID to use"
}


#  resource "hcloud_network" "private_network" {
#   name     = "kubernetes-cluster"
#   ip_range = "10.0.0.0/16"
# }

# resource "hcloud_network_subnet" "private_network_subnet" {
#   type         = "cloud"
#   network_id   = var.network_id
#   network_zone = "eu-central"
#   ip_range     = "10.0.1.0/24"
# }

resource "hcloud_server" "master-node" {
  name        = "master-node"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "hel1"
  labels = {
    k8s = true
    k8s-role = "control-plane"
  }
  
  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }
  network {
    network_id = var.network_id
    # IP Used by the master node, needs to be static
    # Here the worker nodes will use 10.0.1.1 to communicate with the master node
    ip = "10.0.1.1"
  }
  user_data = file("${path.module}/cloud-init.yaml")

  # If we don't specify this, Terraform will create the resources in parallel
  # We want this node to be created after the private network is created
  # depends_on = [hcloud_network_subnet.private_network_subnet]
}

resource "hcloud_server" "worker-nodes" {
  count = 1

  # The name will be worker-node-0, worker-node-1, worker-node-2...
  name        = "worker-node-${count.index}"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "hel1"
  labels = {
    k8s = true
    k8s-role = "worker"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }
  network {
    network_id = var.network_id
    ip         = "10.0.1.1${count.index}"
  }
  user_data = templatefile("${path.module}/cloud-init-worker.yaml", {
    K3S_PRIVATE_KEY = split("\n", file("${path.module}/../keys/id_ed25519.k8s-dev")),
    NODE_IP="10.0.1.1${count.index}"
  })

  depends_on = [hcloud_server.master-node]
}
