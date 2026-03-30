

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


resource "kubernetes_namespace_v1" "buildkit" {
  metadata {
    name = "buildkit"
    labels = {
      buildkit = true
    }
  }
}

resource "kubernetes_manifest" "buildkit-selfsigned-clusterissuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Issuer"
    metadata = {
      name      = "buildkit-selfsigned"
      namespace = "buildkit"
    }
    spec = {
      selfSigned = {}
    }
  }
}

resource "kubernetes_manifest" "buildkit-root-cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "buildkit-ca"
      namespace = "buildkit"
    }
    spec = {
      isCA       = true
      commonName = "buildkit-ca"
      secretName = "buildkit-ca-secret"
      issuerRef = {
        name = "buildkit-selfsigned"
      }
    }
  }
}

resource "kubernetes_manifest" "buildkit-ca-issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Issuer"
    metadata = {
      name      = "buildkit-ca-issuer"
      namespace = "buildkit"
    }
    spec = {
      ca = {
        secretName = "buildkit-ca-secret"
      }
    }
  }
}

resource "kubernetes_manifest" "buildkit-daemon-cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "buildkit-daemon"
      namespace = "buildkit"
    }
    spec = {
      secretName = "buildkit-daemon-certs"
      issuerRef = {
        name = "buildkit-ca-issuer"
      }
      commonName = "buildkitd"
      dnsNames = [
        "buildkitd",
        "buildkitd.buildkit",
        "buildkitd.buildkit.svc",
        "buildkitd.buildkit.svc.cluster.local"
      ]
      usages = [
        "server auth",
        "client auth"
      ]
    }
  }
}


resource "kubernetes_manifest" "buildkit-client-cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "buildkit-client"
      namespace = "buildkit"
    }
    spec = {
      secretName = "buildkit-client-certs"
      issuerRef = {
        name = "buildkit-ca-issuer"
      }
      commonName = "buildkitd-client"
      usages = [
        "client auth"
      ]
    }
  }
}


resource "kubernetes_deployment_v1" "buildkit-deployment-arm64" {
  depends_on       = [kubernetes_namespace_v1.buildkit]
  wait_for_rollout = false

  metadata {
    name      = "buildkitd"
    namespace = "buildkit"

    labels = {
      app = "buildkitd"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "buildkitd"
      }
    }

    template {
      metadata {
        labels = {
          app = "buildkitd"
        }

        annotations = {
          "container.apparmor.security.beta.kubernetes.io/buildkitd" = "unconfined"
        }
      }

      spec {
        restart_policy = "Always"

        container {
          name  = "buildkitd"
          image = "moby/buildkit:master-rootless"
          args = [
            "--addr", "unix:///run/user/1000/buildkit/buildkitd.sock",
            "--addr", "tcp://0.0.0.0:1234",
            "--tlscacert", "/certs/ca.crt",
            "--tlscert", "/certs/tls.crt",
            "--tlskey", "/certs/tls.key",
            "--oci-worker-no-process-sandbox"
          ]

          readiness_probe {
            exec {
              command = ["buildctl", "debug", "workers"]
            }
            initial_delay_seconds = 5
            period_seconds        = 30
          }

          liveness_probe {
            exec {
              command = ["buildctl", "debug", "workers"]
            }
            initial_delay_seconds = 5
            period_seconds        = 30
          }

          security_context {
            seccomp_profile {
              type = "Unconfined"
            }

            run_as_user  = 1000
            run_as_group = 1000
          }

          port {
            container_port = 1234
          }

          volume_mount {
            name       = "certs"
            read_only  = true
            mount_path = "/certs"
          }

        }

        volume {
          name = "certs"
          secret {
            secret_name = "buildkit-daemon-certs"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "buildkitd" {
  metadata {
    name      = "buildkitd"
    namespace = "buildkit"
  }

  spec {
    selector = {
      app = "buildkitd"
    }

    port {
      port        = 1234
      target_port = 1234
    }
  }
}
