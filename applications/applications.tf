

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      # Here we use version 1.56.0, this may change in the future
      version = "1.56.0"
    }
    kubernetes = {
        source = "hashicorp/kubernetes",
    }
    helm = {
        source = "hashicorp/helm"
    }
  }
}

/// -- VARIABLES 
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

variable "hcloud_token" {
  sensitive = true
  type      = string
}

/// -- PROVIDERS

provider "hcloud" {
  token = var.hcloud_token
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

/// -- DATA

data "hcloud_network" "by_name" {
    name = "kubernetes-cluster"
}

/// -- MODULES

module "pangolin" {
  source = "./pangolin"

  depends_on = [ ]

  network_id = data.hcloud_network.by_name.id
  network_ip = "10.0.1.3"
}



module "forgejo" {
  source = "./forgejo"
  depends_on = [  ]

  network_id = data.hcloud_network.by_name.id
  network_ip = "10.0.1.4"

  forgejo_bucket_access_key = var.forgejo_bucket_access_key
  forgejo_bucket_endpoint = var.forgejo_bucket_endpoint
  forgejo_bucket_secret_key = var.forgejo_bucket_secret_key
}


module "jellyfin" {
  source = "./jellyfin"
  depends_on = [ ]
}