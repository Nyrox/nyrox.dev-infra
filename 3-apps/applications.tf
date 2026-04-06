

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
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

/// -- MODULES

module "gateway" {
  source     = "./gateway"
  depends_on = []
}

variable "newt_endpoint" {
  type        = string
  description = "Pangolin endpoint URL for the Newt relay ingress"
}

variable "newt_id" {
  type        = string
  description = "Newt client ID from the Pangolin dashboard"
}

variable "newt_secret" {
  type        = string
  description = "Newt client secret from the Pangolin dashboard"
  sensitive   = true
}

module "pangolin" {
  source = "./pangolin"

  depends_on = []

  newt_endpoint = var.newt_endpoint
  newt_id       = var.newt_id
  newt_secret   = var.newt_secret
}

module "jellyfin" {
  source     = "./jellyfin"
  depends_on = []
}

module "buildkit" {
  source     = "./buildkit"
  depends_on = []
}

module "motoki-playground" {
  source     = "./motoki-playground"
  depends_on = []
}

variable "freshrss_admin_password" {
  type      = string
  sensitive = true
}

variable "freshrss_api_password" {
  type      = string
  sensitive = true
}

variable "freshrss_admin_email" {
  type    = string
  default = "admin@nyrox.dev"
}

module "freshrss" {
  source     = "./freshrss"
  depends_on = []

  admin_password = var.freshrss_admin_password
  api_password   = var.freshrss_api_password
  admin_email    = var.freshrss_admin_email
}

module "lock-in-reader" {
  source     = "./lock-in-reader"
  depends_on = []
}
