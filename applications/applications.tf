

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
  type        = string
  description = "minio-compatible forgejo bucket access key"
  sensitive   = false
}

variable "forgejo_bucket_secret_key" {
  type        = string
  description = "minio-compatible forgejo bucket access key"
  sensitive   = true
}

variable "forgejo_bucket_endpoint" {
  type        = string
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

variable "pangolin_acme_email" {
  type        = string
  description = "Email address for pangolin Let's Encrypt ACME registration"
}

variable "pangolin_server_secret" {
  type        = string
  description = "Pangolin server secret (min 32 chars)"
  sensitive   = true
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

  network_id    = data.hcloud_network.by_name.id
  network_ip    = "10.0.1.3"
  acme_email    = var.pangolin_acme_email
  server_secret = var.pangolin_server_secret

  newt_endpoint = var.newt_endpoint
  newt_id       = var.newt_id
  newt_secret   = var.newt_secret
}



module "forgejo" {
  source     = "./forgejo"
  depends_on = []

  network_id = data.hcloud_network.by_name.id
  network_ip = "10.0.1.4"

  forgejo_bucket_access_key = var.forgejo_bucket_access_key
  forgejo_bucket_endpoint   = var.forgejo_bucket_endpoint
  forgejo_bucket_secret_key = var.forgejo_bucket_secret_key
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