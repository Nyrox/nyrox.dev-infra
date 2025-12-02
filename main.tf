# Tell Terraform to include the hcloud provider
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      # Here we use version 1.56.0, this may change in the future
      version = "1.56.0"
    }
  }
}

# Declare the hcloud_token variable from .tfvars
variable "hcloud_token" {
  sensitive = true # Requires terraform >= 0.14
}

# Configure the Hetzner Cloud Provider with your token
provider "hcloud" {
  token = var.hcloud_token
}

# resource "hcloud_network" "private_network" {
#   name     = "kubernetes-cluster"
#   ip_range = "10.0.0.0/16"
# }

# resource "hcloud_network_subnet" "private_network_subnet" {
#   type         = "cloud"
#   network_id   = hcloud_network.private_network.id
#   network_zone = "eu-central"
#   ip_range     = "10.0.1.0/24"
# }

# output "network_id" {
#   value = hcloud_network.private_network.id
# }

# resource "hcloud_server" "master-node" {
#   name        = "master-node"
#   image       = "ubuntu-24.04"
#   server_type = "cax11"
#   location    = "hel1"
#   public_net {
#     ipv4_enabled = true
#     ipv6_enabled = true
#   }
#   network {
#     network_id = hcloud_network.private_network.id
#     # IP Used by the master node, needs to be static
#     # Here the worker nodes will use 10.0.1.1 to communicate with the master node
#     ip         = "10.0.1.1"
#   }
#   user_data = file("${path.module}/cloud-init.yaml")

#   # If we don't specify this, Terraform will create the resources in parallel
#   # We want this node to be created after the private network is created
#   depends_on = [hcloud_network_subnet.private_network_subnet]
# }

# resource "hcloud_server" "worker-nodes" {
#   count = 1
  
#   # The name will be worker-node-0, worker-node-1, worker-node-2...
#   name        = "worker-node-${count.index}"
#   image       = "ubuntu-24.04"
#   server_type = "cax11"
#   location    = "hel1"
#   public_net {
#     ipv4_enabled = true
#     ipv6_enabled = true
#   }
#   network {
#     network_id = hcloud_network.private_network.id
#   }
#   user_data = file("${path.module}/cloud-init-worker.yaml")

#   depends_on = [hcloud_network_subnet.private_network_subnet, hcloud_server.master-node]
# }

variable "network_id" {
  type = number
}

module "pangolin" {
  source = "./pangolin"

  depends_on = [ ]

  network_id = var.network_id
}

variable "forgejo_bucket_access_key" {
    type = string
    description = "minio-compatible forgejo bucket access key"
    sensitive = false
}

variable "forgejo_bucket_secret_key" {
    type = string
    description = "minio-compatible forgejo bucket access key"
    sensitive = true
}

variable "forgejo_bucket_endpoint" {
    type = string
    description = "minion-compatible s3 endpoint"
}


module "forgejo" {
  source = "./forgejo"
  depends_on = [  ]

  network_id = var.network_id
  forgejo_bucket_access_key = var.forgejo_bucket_access_key
  forgejo_bucket_endpoint = var.forgejo_bucket_endpoint
  forgejo_bucket_secret_key = var.forgejo_bucket_secret_key
}