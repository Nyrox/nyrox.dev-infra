
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

variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "network_id" {
  type = string
}


// --- RESOURCES
resource "kubernetes_secret_v1" "hcloud" {
  metadata {
    name      = "hcloud"
    namespace = "kube-system"
  }

  data = {
    token   = var.hcloud_token
    network = var.network_id
  }
}

resource "helm_release" "hetzner-csi-driver" {
  name       = "hcloud-csi"
  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-csi"

  namespace = "kube-system"
  wait      = false
}

resource "helm_release" "hetzner-cloud-controller" {
  name       = "hccm"
  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-cloud-controller-manager"
  depends_on = [kubernetes_secret_v1.hcloud]

  namespace = "kube-system"
  wait      = false

  set = [{
    name  = "networking.enabled"
    value = true
    }, {
    name  = "networking.clusterCIDR"
    value = "10.42.0.0/16"
  }]
}

// --- CERT MANAGER

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"

  create_namespace = true
  namespace        = "cert-manager"

  set = [{
    name  = "config.apiVersion"
    value = "controller.config.cert-manager.io/v1alpha1"
    }, {
    name  = "config.kind"
    value = "ControllerConfiguration"
    }, {
    name  = "config.enableGatewayAPI"
    value = true
    }, {
    name  = "crds.enabled"
    value = true
  }]
}

resource "kubernetes_manifest" "cert-manager-cluster-issuer" {
  depends_on = [helm_release.cert-manager]
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email  = "acme+root@nyrox.dev"
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "issuer-account-key"
        }

        solvers = [{
          http01 = {
            gatewayHTTPRoute = {
              parentRefs = [{
                name      = "main-gateway"
                namespace = "nginx-gateway"
                kind      = "Gateway"
              }]
            }
          }
        }]
      }
    }
  }
}

// --- NGINX FABRIC

resource "terraform_data" "install-k8s-gateway-crd" {
  provisioner "local-exec" {
    command = "kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml"
  }
}

resource "terraform_data" "install-nginx-fabric-gateway-crd" {
  depends_on = [terraform_data.install-k8s-gateway-crd]
  provisioner "local-exec" {
    command = "kubectl kustomize \"https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.2.1\" | kubectl apply -f -"
  }
}

resource "helm_release" "nginx-gateway-fabric" {
  depends_on = [terraform_data.install-nginx-fabric-gateway-crd]

  name       = "ngf"
  repository = "oci://ghcr.io/nginx/charts"
  chart      = "nginx-gateway-fabric"

  namespace        = "nginx-gateway"
  create_namespace = true
}

resource "kubernetes_manifest" "nginx-gabric-gateway" {
  depends_on = [helm_release.nginx-gateway-fabric]
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
        }
      ]

      infrastructure = {
        annotations = {
          "load-balancer.hetzner.cloud/name"     = "main-gateway-lb"
          "load-balancer.hetzner.cloud/location" = "fsn1"
          "load-balancer.hetzner.cloud/use-private-ip" : true
          "load-balancer.hetzner.cloud/uses-proxyprotocol" : false
        }
      }
    }
  }
}
