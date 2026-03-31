
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
  type      = string
}

variable "tekton_dashboard_oauth_client_secret" {
  sensitive = true
  type      = string
}

variable "forgejo_registry_username" {
  type        = string
  description = "Username for the Forgejo container registry at git.nyrox.dev"
}

variable "forgejo_registry_token" {
  type        = string
  description = "Forgejo access token for pulling from git.nyrox.dev container registry"
  sensitive   = true
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

module "hetzner-k8s" {
  source     = "./hetzner-k8s-integration"
  depends_on = []

  hcloud_token = var.hcloud_token
  network_id   = data.hcloud_network.by_name.id

  tekton_dashboard_oauth_client_id     = var.tekton_dashboard_oauth_client_id
  tekton_dashboard_oauth_client_secret = var.tekton_dashboard_oauth_client_secret

  forgejo_registry_username = var.forgejo_registry_username
  forgejo_registry_token    = var.forgejo_registry_token
}