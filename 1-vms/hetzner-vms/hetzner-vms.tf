
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.56.0"
    }
  }
}

variable "network_id" {
  type        = number
  description = "Hetzner Network ID to use"
}

resource "hcloud_server" "master-node" {
  name        = "master-node"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "hel1"
  labels = {
    k8s      = true
    k8s-role = "control-plane"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }
  network {
    network_id = var.network_id
    ip         = "10.0.1.1"
  }
  user_data = file("${path.module}/cloud-init.yaml")
}

resource "hcloud_server" "worker-nodes" {
  count = 1

  name        = "worker-node-${count.index}"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "hel1"
  labels = {
    k8s      = true
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
    NODE_IP         = "10.0.1.1${count.index}"
  })

  depends_on = [hcloud_server.master-node]
}
