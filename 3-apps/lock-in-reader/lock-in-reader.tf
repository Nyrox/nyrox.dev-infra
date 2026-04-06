terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.56.0"
    }
  }
}

data "hcloud_zone" "nyrox-dev" {
  name = "nyrox.dev"
}

data "hcloud_load_balancer" "main-gateway" {
  name = "main-gateway-lb"
}

resource "hcloud_zone_rrset" "lock-in-reader-nyrox-dev-A" {
  zone = data.hcloud_zone.nyrox-dev.id
  type = "A"
  name = "lock-in-reader"
  ttl  = 3600

  records = [{
    value = data.hcloud_load_balancer.main-gateway.ipv4, comment = "K8s main gateway LB"
  }]
}

resource "kubernetes_namespace_v1" "lock-in-reader" {
  metadata {
    name = "lock-in-reader"
  }
}

resource "kubernetes_deployment_v1" "lock-in-reader" {
  depends_on = [kubernetes_namespace_v1.lock-in-reader]
  metadata {
    name      = "lock-in-reader"
    namespace = "lock-in-reader"
    labels = {
      app = "lock-in-reader"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "lock-in-reader"
      }
    }

    template {
      metadata {
        labels = {
          app = "lock-in-reader"
        }
      }

      spec {
        image_pull_secrets {
          name = "forgejo-registry"
        }

        container {
          name  = "lock-in-reader"
          image = "git.nyrox.dev/nyrox/lock-in-reader:latest"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "lock-in-reader" {
  depends_on = [kubernetes_namespace_v1.lock-in-reader]

  metadata {
    name      = "lock-in-reader"
    namespace = "lock-in-reader"
  }

  spec {
    selector = {
      app = "lock-in-reader"
    }

    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_manifest" "lock-in-reader-http-route" {
  depends_on = [kubernetes_namespace_v1.lock-in-reader]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "lock-in-reader-http"
      namespace = "lock-in-reader"
    }
    spec = {
      hostnames = ["lock-in-reader.nyrox.dev"]
      parentRefs = [{
        name        = "main-gateway"
        namespace   = "nginx-gateway"
        sectionName = "lock-in-reader"
      }]
      rules = [{
        backendRefs = [{
          name      = "lock-in-reader"
          namespace = "lock-in-reader"
          port      = 80
        }]
      }]
    }
  }
}
