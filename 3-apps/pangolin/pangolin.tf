
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

variable "newt_endpoint" {
  type        = string
  description = "Pangolin endpoint URL for the Newt relay ingress (e.g. https://relay.nyrox.dev)"
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

module "newt" {
  source = "./newt"

  newt_endpoint = var.newt_endpoint
  newt_id       = var.newt_id
  newt_secret   = var.newt_secret
}
