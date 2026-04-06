terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

// The nginx-gateway-fabric Helm release (platform layer) must be deployed
// before this resource is applied. That ordering is enforced by applying
// core-infra before applications, not by a Terraform depends_on.
resource "kubernetes_manifest" "main-gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "main-gateway"
      namespace = "nginx-gateway"
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      }
    }
    spec = {
      gatewayClassName = "nginx"
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
        },
        {
          name     = "jellyfin"
          port     = 443
          protocol = "HTTPS"
          hostname = "jellyfin.nyrox.dev"
          tls = {
            mode = "Terminate"
            certificateRefs = [{
              kind = "Secret"
              name = "jellyfin-nyrox-dev-secret"
            }]
          }
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "kubernetes.io/metadata.name" = "jellyfin"
                }
              }
            }
          }
        },
        {
          name     = "syncthing.jellyfin"
          port     = 443
          protocol = "HTTPS"
          hostname = "syncthing.jellyfin.nyrox.dev"
          tls = {
            mode = "Terminate"
            certificateRefs = [{
              kind = "Secret"
              name = "syncthing-jellyfin-nyrox-dev-secret"
            }]
          }
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "kubernetes.io/metadata.name" = "jellyfin"
                }
              }
            }
          }
        },
        {
          name     = "syncthing.jellyfin-tcp"
          port     = 22000
          protocol = "TCP"
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "kubernetes.io/metadata.name" = "jellyfin"
                }
              }
            }
          }
        },
        {
          name     = "syncthing.jellyfin-udp"
          port     = 22000
          protocol = "UDP"
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "kubernetes.io/metadata.name" = "jellyfin"
                }
              }
            }
          }
        },
        {
          name     = "motoki-playground"
          port     = 443
          protocol = "HTTPS"
          hostname = "motoki-playground.nyrox.dev"
          tls = {
            mode = "Terminate"
            certificateRefs = [{
              kind = "Secret"
              name = "motoki-playground-nyrox-dev-secret"
            }]
          }
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "kubernetes.io/metadata.name" = "motoki-playground"
                }
              }
            }
          }
        },
        {
          name     = "rss"
          port     = 443
          protocol = "HTTPS"
          hostname = "rss.nyrox.dev"
          tls = {
            mode = "Terminate"
            certificateRefs = [{
              kind = "Secret"
              name = "rss-nyrox-dev-secret"
            }]
          }
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "kubernetes.io/metadata.name" = "freshrss"
                }
              }
            }
          }
        },
        {
          name     = "tekton-dashboard"
          port     = 443
          protocol = "HTTPS"
          hostname = "tekton.nyrox.dev"
          tls = {
            mode = "Terminate"
            certificateRefs = [{
              kind = "Secret"
              name = "tekton-nyrox-dev-secret"
            }]
          }
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "kubernetes.io/metadata.name" = "tekton-aux"
                }
              }
            }
          }
        },
        {
          name     = "lock-in-reader"
          port     = 443
          protocol = "HTTPS"
          hostname = "lock-in-reader.nyrox.dev"
          tls = {
            mode = "Terminate"
            certificateRefs = [{
              kind = "Secret"
              name = "lock-in-reader-nyrox-dev-secret"
            }]
          }
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "kubernetes.io/metadata.name" = "lock-in-reader"
                }
              }
            }
          }
        }
      ]

      infrastructure = {
        annotations = {
          "load-balancer.hetzner.cloud/name"               = "main-gateway-lb"
          "load-balancer.hetzner.cloud/location"           = "fsn1"
          "load-balancer.hetzner.cloud/use-private-ip"     = true
          "load-balancer.hetzner.cloud/uses-proxyprotocol" = false
        }
      }
    }
  }
}
