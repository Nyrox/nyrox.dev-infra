
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

resource "kubernetes_namespace_v1" "newt" {
  metadata {
    name = "newt"
  }
}

resource "kubernetes_secret_v1" "newt-cred" {
  depends_on = [kubernetes_namespace_v1.newt]

  metadata {
    name      = "newt-cred"
    namespace = "newt"
  }

  data = {
    PANGOLIN_ENDPOINT = var.newt_endpoint
    NEWT_ID           = var.newt_id
    NEWT_SECRET       = var.newt_secret
  }
}

resource "helm_release" "k8s-main-relay-ingress" {
  depends_on = [kubernetes_secret_v1.newt-cred]

  name       = "k8s-main-relay-ingress"
  repository = "https://charts.fossorial.io"
  chart      = "newt"
  namespace  = "newt"

  values = [
    yamlencode({
      newtInstances = [{
        name    = "main"
        enabled = true
        auth = {
          existingSecretName = "newt-cred"
          keys = {
            endpointKey = "PANGOLIN_ENDPOINT"
            idKey       = "NEWT_ID"
            secretKey   = "NEWT_SECRET"
          }
        }
      }]
    })
  ]
}
