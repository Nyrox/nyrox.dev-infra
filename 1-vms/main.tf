
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.56.0"
    }
  }
}

/// -- VARIABLES

variable "hcloud_token" {
  sensitive = true
  type      = string
}

variable "forgejo_bucket_access_key" {
  type        = string
  description = "minio-compatible forgejo bucket access key"
  sensitive   = false
}

variable "forgejo_bucket_secret_key" {
  type        = string
  description = "minio-compatible forgejo bucket secret key"
  sensitive   = true
}

variable "forgejo_bucket_endpoint" {
  type        = string
  description = "minio-compatible s3 endpoint"
}

variable "pangolin_acme_email" {
  type        = string
  description = "Email address for pangolin Let's Encrypt ACME registration"
}

variable "pangolin_server_secret" {
  type        = string
  description = "Pangolin server secret (min 32 chars)"
  sensitive   = true
}

/// -- PROVIDERS

provider "hcloud" {
  token = var.hcloud_token
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

module "forgejo" {
  source = "./forgejo"

  network_id = data.hcloud_network.by_name.id
  network_ip = "10.0.1.4"

  forgejo_bucket_access_key = var.forgejo_bucket_access_key
  forgejo_bucket_endpoint   = var.forgejo_bucket_endpoint
  forgejo_bucket_secret_key = var.forgejo_bucket_secret_key
}

module "pangolin" {
  source = "./pangolin"

  network_id    = data.hcloud_network.by_name.id
  network_ip    = "10.0.1.3"
  acme_email    = var.pangolin_acme_email
  server_secret = var.pangolin_server_secret
}
