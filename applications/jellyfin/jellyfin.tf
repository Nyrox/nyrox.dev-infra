terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes",
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

resource "kubernetes_namespace_v1" "jellyfin" {
  metadata {
    name = "jellyfin"
    labels = {
      jellyfin = true
    }
  }
}

resource "kubernetes_storage_class_v1" "retained-hcloud-volume" {
  metadata {
    name = "retained-hcloud-volumes"
  }

  storage_provisioner    = "csi.hetzner.cloud"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
}


resource "kubernetes_persistent_volume_claim_v1" "jellyfin-media-volume" {
  depends_on       = [kubernetes_namespace_v1.jellyfin, kubernetes_storage_class_v1.retained-hcloud-volume]
  wait_until_bound = false

  metadata {
    name      = "jellyfin-media-pvc"
    namespace = "jellyfin"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "retained-hcloud-volumes"

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "jellyfin-config-volume" {
  depends_on       = [kubernetes_namespace_v1.jellyfin, kubernetes_storage_class_v1.retained-hcloud-volume]
  wait_until_bound = false

  metadata {
    name      = "jellyfin-config-pvc"
    namespace = "jellyfin"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "retained-hcloud-volumes"

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "syncthing-config-volume" {
  depends_on       = [kubernetes_namespace_v1.jellyfin, kubernetes_storage_class_v1.retained-hcloud-volume]
  wait_until_bound = false

  metadata {
    name      = "syncthing-config-pvc"
    namespace = "jellyfin"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "retained-hcloud-volumes"

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "jellyfin-deployment" {
  depends_on = [
    kubernetes_persistent_volume_claim_v1.jellyfin-config-volume,
    kubernetes_persistent_volume_claim_v1.jellyfin-media-volume,
    kubernetes_persistent_volume_claim_v1.syncthing-config-volume
  ]
  wait_for_rollout = false

  metadata {
    name      = "jellyfin"
    namespace = "jellyfin"
  }

  spec {
    selector {
      match_labels = {
        app = "jellyfin"
      }
    }

    template {
      metadata {
        labels = {
          app = "jellyfin"
        }
      }

      spec {
        restart_policy = "Always"

        security_context {
          fs_group = 1000
        }

        volume {
          name = "media"
          persistent_volume_claim {
            claim_name = "jellyfin-media-pvc"
          }
        }

        volume {
          name = "jellyfin-config"
          persistent_volume_claim {
            claim_name = "jellyfin-config-pvc"
          }
        }

        volume {
          name = "syncthing-config"

          persistent_volume_claim {
            claim_name = "syncthing-config-pvc"
          }
        }

        /// Jellyfin container
        container {
          name              = "jellyfin"
          image             = "docker.io/jellyfin/jellyfin"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8096
            protocol       = "TCP"
          }

          volume_mount {
            mount_path = "/data/media"
            name       = "media"
          }

          volume_mount {
            mount_path = "/config"
            name       = "jellyfin-config"
          }

          env {
            name = "NODE_NAME"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "spec.nodeName"
              }
            }
          }

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "metadata.name"
              }
            }
          }

          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "metadata.namespace"
              }
            }
          }
        }

        /// syncthing
        container {
          name  = "syncthing"
          image = "lscr.io/linuxserver/syncthing:latest"

          port {
            name           = "web-ui"
            container_port = 8384
          }

          port {
            name           = "syncthing-tcp"
            container_port = 22000
            protocol       = "TCP"
          }

          port {
            name           = "syncthing-udp"
            container_port = 22000
            protocol       = "UDP"
          }

          volume_mount {
            name       = "syncthing-config"
            mount_path = "/config"
          }

          volume_mount {
            name       = "media"
            mount_path = "/data/media"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "jellyfin-service" {
  metadata {
    name      = "jellyfin"
    namespace = "jellyfin"
    labels = {
      app = "jellyfin"
    }
  }

  spec {
    port {
      name        = "web"
      port        = 8096
      protocol    = "TCP"
      target_port = 8096
    }

    selector = {
      app = "jellyfin"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_service_v1" "syncthing-service" {
  metadata {
    name      = "syncthing"
    namespace = "jellyfin"
    labels = {
      app = "jellyfin"
    }
  }

  spec {
    port {
      name        = "web"
      port        = 8384
      protocol    = "TCP"
      target_port = 8384
    }

    port {
      name        = "tcp"
      port        = 32222
      protocol    = "TCP"
      target_port = 32222
    }

    port {
      name        = "udp"
      port        = 32222
      protocol    = "UDP"
      target_port = 32222
    }

    selector = {
      app = "jellyfin"
    }

    type = "ClusterIP"
  }
}



resource "kubernetes_manifest" "jellyfin-http-route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "jellyfin-http"
      namespace = "jellyfin"
    }

    spec = {
      hostnames = ["jellyfin.nyrox.dev"]
      parentRefs = [{
        name          = "main-gateway"
        namespace     = "nginx-gateway"
        selectionName = "jellyfin"
      }]
      rules = [
        {
          backendRefs = [{
            name      = "jellyfin"
            namespace = "jellyfin"
            port      = 8096
          }]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "syncthing-http-route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "syncthing-http"
      namespace = "jellyfin"
    }

    spec = {
      hostnames = ["syncthing.jellyfin.nyrox.dev"]
      parentRefs = [{
        name          = "main-gateway"
        namespace     = "nginx-gateway"
        selectionName = "jellyfin"
      }]
      rules = [
        {
          backendRefs = [{
            name      = "syncthing"
            namespace = "jellyfin"
            port      = 8384
          }]
        }
      ]
    }
  }
}


resource "kubernetes_manifest" "syncthing-tcp-route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1alpha2"
    kind       = "TCPRoute"
    metadata = {
      name      = "syncthing-tcp"
      namespace = "jellyfin"
    }

    spec = {
      parentRefs = [{
        name          = "main-gateway"
        namespace     = "nginx-gateway"
        selectionName = "jellyfin"
      }]
      rules = [
        {
          backendRefs = [{
            name      = "syncthing"
            namespace = "jellyfin"
            port      = 22000
          }]
        }
      ]
    }
  }
}


resource "kubernetes_manifest" "syncthing-udp-route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1alpha2"
    kind       = "UDPRoute"
    metadata = {
      name      = "syncthing-udp"
      namespace = "jellyfin"
    }

    spec = {
      parentRefs = [{
        name          = "main-gateway"
        namespace     = "nginx-gateway"
        selectionName = "jellyfin"
      }]
      rules = [
        {
          backendRefs = [{
            name      = "syncthing"
            namespace = "jellyfin"
            port      = 22000
          }]
        }
      ]
    }
  }
}
