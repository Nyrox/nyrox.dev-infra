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
    }
}

resource "kubernetes_storage_class_v1" "retained-hcloud-volume" {
    metadata {
      name = "retained-hcloud-volumes"
    }

    storage_provisioner = "csi.hetzner.cloud"
    reclaim_policy = "Retain"
    volume_binding_mode = "WaitForFirstConsumer"
    allow_volume_expansion = true
}

resource "kubernetes_persistent_volume_claim_v1" "jellyfin-media-volume" {
    depends_on = [ kubernetes_namespace_v1.jellyfin, kubernetes_storage_class_v1.retained-hcloud-volume ]
    wait_until_bound = false

    metadata {
      name = "jellyfin-media-pvc"
      namespace = "jellyfin"
    }

    spec {
        access_modes = [ "ReadWriteOnce" ]
        storage_class_name = "retained-hcloud-volumes"
        resources {
            requests = {
                storage = "10Gi"
            }
        }
    }
}

resource "kubernetes_persistent_volume_claim_v1" "jellyfin-config-volume" {
    depends_on = [ kubernetes_namespace_v1.jellyfin, kubernetes_storage_class_v1.retained-hcloud-volume ]
    wait_until_bound = false

    metadata {
      name = "jellyfin-config-pvc"
      namespace = "jellyfin"
    }

    spec {
        access_modes = [ "ReadWriteOnce" ]
        storage_class_name = "retained-hcloud-volumes"
        resources {
            requests = {
              storage = "10Gi"
            }
        }
    }
}


resource "kubernetes_deployment_v1" "jellyfin-deployment" {
    depends_on = [ kubernetes_persistent_volume_claim_v1.jellyfin-config-volume, kubernetes_persistent_volume_claim_v1.jellyfin-media-volume ]

    metadata {
      name = "jellyfin"
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

                volume {
                    name = "media"
                    persistent_volume_claim {
                      claim_name = "jellyfin-media-pvc"
                    }
                }

                volume {
                  name = "config"
                  persistent_volume_claim {
                    claim_name = "jellyfin-config-pvc"
                  }
                }

                container {
                    name = "jellyfin"
                    image = "docker.io/jellyfin/jellyfin"
                    image_pull_policy = "IfNotPresent"
                    
                    port {
                      container_port = 8096
                      protocol = "TCP"
                    }

                    volume_mount {
                      mount_path = "/data/media"
                      name = "media"
                    }

                    volume_mount {
                      mount_path = "/config"
                      name = "config"
                    }

                    env {
                      name = "NODE_NAME"
                      value_from {
                        field_ref {
                          api_version = "v1"
                          field_path = "spec.nodeName"
                        }
                      }
                    }

                    env {
                      name = "POD_NAME"
                      value_from {
                        field_ref {
                          api_version = "v1"
                          field_path = "metadata.name"
                        }
                      }
                    }

                    env {
                        name = "POD_NAMESPACE"
                        value_from {
                            field_ref {
                              api_version = "v1"
                              field_path = "metadata.namespace"
                            }
                        }
                    }
                }
            }
        }
    }
}