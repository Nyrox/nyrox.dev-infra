
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "api_password" {
  type      = string
  sensitive = true
}

variable "admin_email" {
  type    = string
  default = "rss+admin@nyrox.dev"
}

locals {
  namespace = "freshrss"
  hostname  = "rss.nyrox.dev"
}

resource "kubernetes_namespace_v1" "freshrss" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_persistent_volume_claim_v1" "freshrss-data" {
  depends_on       = [kubernetes_namespace_v1.freshrss]
  wait_until_bound = false

  metadata {
    name      = "freshrss-data"
    namespace = local.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "retained-hcloud-volumes"

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "freshrss" {
  depends_on       = [kubernetes_namespace_v1.freshrss]
  wait_for_rollout = false

  metadata {
    name      = "freshrss"
    namespace = local.namespace
    labels = {
      app = "freshrss"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "freshrss"
      }
    }

    template {
      metadata {
        labels = {
          app = "freshrss"
        }
      }

      spec {
        container {
          name  = "freshrss"
          image = "freshrss/freshrss:latest"

          port {
            container_port = 80
          }

          env {
            name  = "TZ"
            value = "UTC"
          }

          env {
            name  = "CRON_MIN"
            value = "*/15"
          }

          # Cluster pod CIDR — trusts X-Forwarded-For from nginx-gateway
          env {
            name  = "TRUSTED_PROXY"
            value = "10.42.0.0/16"
          }

          # Runs once on first boot to configure the installation
          env {
            name  = "FRESHRSS_INSTALL"
            value = "--api-enabled --base-url https://${local.hostname} --default-user admin --db-type sqlite"
          }

          # Runs once on first boot to create the admin user
          env {
            name  = "FRESHRSS_USER"
            value = "--user admin --password ${var.admin_password} --email ${var.admin_email} --api-password ${var.api_password}"
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/www/FreshRSS/data"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 30
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.freshrss-data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "freshrss" {
  depends_on = [kubernetes_namespace_v1.freshrss]

  metadata {
    name      = "freshrss"
    namespace = local.namespace
  }

  spec {
    selector = {
      app = "freshrss"
    }

    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_manifest" "freshrss-http-route" {
  depends_on = [kubernetes_namespace_v1.freshrss]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "freshrss-http"
      namespace = local.namespace
    }
    spec = {
      hostnames = [local.hostname]
      parentRefs = [{
        name        = "main-gateway"
        namespace   = "nginx-gateway"
        sectionName = "rss"
      }]
      rules = [{
        backendRefs = [{
          name      = "freshrss"
          namespace = local.namespace
          port      = 80
        }]
      }]
    }
  }
}
