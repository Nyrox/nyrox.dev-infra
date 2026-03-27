
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
variable "hcloud_token" {
  sensitive = true
  type      = string
}

variable "tekton_dashboard_oauth_client_id" {
    sensitive = true
    type = string
}

variable "tekton_dashboard_oauth_client_secret" {
    sensitive = true
    type = string
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

module "hetzner-vms" {
  source     = "./hetzner-vms"
  network_id = data.hcloud_network.by_name.id
}

module "hetzner-k8s" {
  source     = "./hetzner-k8s-integration"
  depends_on = []

  hcloud_token = var.hcloud_token
  network_id   = data.hcloud_network.by_name.id

  tekton_dashboard_oauth_client_id = var.tekton_dashboard_oauth_client_id
  tekton_dashboard_oauth_client_secret = var.tekton_dashboard_oauth_client_secret
}