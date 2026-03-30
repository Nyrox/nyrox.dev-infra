terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

resource "kubernetes_deployment_v1" "motoki-playground" {
  metadata {
    name      = "motoki-playground"
    namespace = "motoki-playground"
    labels = {
      app = "motoki-playground"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "motoki-playground"
      }
    }

    template {
      metadata {
        labels = {
          app = "motoki-playground"
        }
      }

      spec {
        image_pull_secrets {
          name = "forgejo-registry"
        }

        container {
          name  = "motoki-playground"
          image = "git.nyrox.dev/nyrox/motoki-playground:latest"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "motoki-playground" {
  metadata {
    name      = "motoki-playground"
    namespace = "motoki-playground"
  }

  spec {
    selector = {
      app = "motoki-playground"
    }

    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_manifest" "motoki-playground-http-route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "motoki-playground-http"
      namespace = "motoki-playground"
    }
    spec = {
      hostnames = ["motoki-playground.nyrox.dev"]
      parentRefs = [{
        name        = "main-gateway"
        namespace   = "nginx-gateway"
        sectionName = "motoki-playground"
      }]
      rules = [{
        backendRefs = [{
          name      = "motoki-playground"
          namespace = "motoki-playground"
          port      = 80
        }]
      }]
    }
  }
}
