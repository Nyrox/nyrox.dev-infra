
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      # Here we use version 1.56.0, this may change in the future
      version = "1.56.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

variable "network_id" {
  type        = number
  description = "Hetzner Network ID to use"
}

variable "network_ip" {
  type        = string
  description = "Networked IP"
}

variable "domain" {
  type        = string
  description = "Base domain for pangolin (e.g. relay.nyrox.dev)"
  default     = "relay.nyrox.dev"
}

variable "acme_email" {
  type        = string
  description = "Email address for Let's Encrypt ACME registration"
}

variable "server_secret" {
  type        = string
  description = "Pangolin server secret (min 32 chars) for encrypting sensitive data"
  sensitive   = true
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

resource "hcloud_volume" "pangolin-data" {
  name              = "pangolin-data"
  size              = 10
  location          = "hel1"
  format            = "ext4"
  delete_protection = true
}

data "cloudinit_config" "pangolin-cloud-init" {
  part {
    content_type = "text/cloud-config"
    filename     = "cloud.conf"

    content = yamlencode(
      {
        "package_update" : true,
        "groups" : ["docker"],
        "packages" : ["docker.io", "docker-compose-v2"],
        "users" : [
          {
            "name" : "pangolin",
            "groups" : "docker",
            "ssh-authorized-keys" : [
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCpBuzFghRM6bdzirdZzSH9cvC34Rl3Xv7m+kJbtJggyeAzHciXm9suL9ucWPU8zvjnE7mdRcPcN1ypvQute0n/Cmt1wCcOhJqM9nLMsxt0h6y5W4kpRMlSq45aNKg5xVz3EOUdZZoPt5u14BQzo21+ExzZgH3cELlIPvY/nYBBJoZV5tCn6VYs9jWniXb/q7S7cKUninKOZFfiv1j/D38+VsPj51D8WM9tFd5CTplBVUrBsiBwON5CQMvOkkfb7xUxgiDcrIGk5Xgg1VKO4pDqhh8N+E0q8MQJsi+dKd7YJSMKuMWy/AShZQRURVi5wcuVYd91bHHyzZHjRzP/b1CrxjoE94Il4s6yskfV/zN+3famBWld4wvaR/4ab2acWT9eE8DjOSZkYUsN2WaNrZCZDHrShXAewN96cdX3JDWAV2EI9fSrMA45S/13ofpDyR4No1Rzhlpf/I5UwfC8WVuDXXHKOBBwf5bM3cgT8EivU40miorfj8ZMsF/lMBcTm0s= marko@DESKTOP-Q8CO3NO",
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/8YwmkuOgTusH2v7azjCppIf7D1h9L43ok68BvQJ0J mark.junge@criipto.com",
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKCuumXfIEyIWnlfww3nJ72VmXg36eH2dCB7jBu4hcvH K8S Worker Node Key"
            ],
            "sudo" : "ALL=(ALL) NOPASSWD:ALL",
            "shell" : "/bin/bash",
          }
        ],
        "write_files" : [
          {
            "path" : "/opt/pangolin/docker-compose.yml",
            "content" : file("${path.module}/docker-compose.yml")
          },
          {
            "path" : "/opt/pangolin/config/config.yml",
            "content" : templatefile("${path.module}/config.yml.tpl", {
              DOMAIN        = var.domain
              SERVER_SECRET = var.server_secret
            })
          },
          {
            "path" : "/opt/pangolin/config/traefik/traefik_config.yml",
            "content" : templatefile("${path.module}/traefik/traefik_config.yml", {
              ACME_EMAIL = var.acme_email
            })
          },
          {
            "path" : "/opt/pangolin/config/traefik/dynamic_config.yml",
            "content" : templatefile("${path.module}/traefik/dynamic_config.yml", {
              DOMAIN = var.domain
            })
          }
        ],
        "runcmd" : [
          "mkdir -p /opt/pangolin/config/letsencrypt /opt/pangolin/config/traefik/logs /opt/pangolin/config/logs",
          "chown -R pangolin /opt/pangolin"
        ]
      }
    )
  }
}


resource "hcloud_server" "pangolin-master" {
  name        = "pangolin-master"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "hel1"

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = var.network_id
    ip         = var.network_ip
  }

  user_data = data.cloudinit_config.pangolin-cloud-init.rendered
}

resource "hcloud_firewall" "pangolin" {
  name = "pangolin"

  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "51820"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "WireGuard (Gerbil)"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "21820"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "WireGuard alt (Gerbil)"
  }
}

resource "hcloud_firewall_attachment" "pangolin" {
  firewall_id = hcloud_firewall.pangolin.id
  server_ids  = [hcloud_server.pangolin-master.id]
}

resource "hcloud_volume_attachment" "pangolin-data-attachment" {
  volume_id = hcloud_volume.pangolin-data.id
  server_id = hcloud_server.pangolin-master.id

  automount = true
}

resource "terraform_data" "pangolin-remote-setup" {
  triggers_replace = hcloud_server.pangolin-master.id
  depends_on       = [hcloud_volume_attachment.pangolin-data-attachment]

  provisioner "local-exec" {
    command = "ssh-keygen -R ${var.domain}; ssh-keygen -R ${hcloud_server.pangolin-master.ipv4_address}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo ln -s /mnt/HC_Volume_${hcloud_volume_attachment.pangolin-data-attachment.volume_id} /opt/pangolin-data",
      "sudo mkdir -p /opt/pangolin-data/db /opt/pangolin-data/gerbil",
      "sudo chown -R pangolin /opt/pangolin-data",
      // timing: ensure cloud-init packages are installed before continuing
      "sudo apt install -y docker-compose-v2",
      "cd /opt/pangolin && docker compose up -d"
    ]

    connection {
      type        = "ssh"
      user        = "pangolin"
      private_key = file("~/.ssh/id_ed25519.dev-k8s")
      host        = hcloud_server.pangolin-master.ipv4_address
    }
  }
}


data "hcloud_zone" "by_name" {
  name = "nyrox.dev"
}

resource "hcloud_zone_rrset" "relay-nyrox-dev-A-records" {
  zone = data.hcloud_zone.by_name.id
  type = "A"
  name = "relay"
  ttl  = 3600

  records = [{
    value = hcloud_server.pangolin-master.ipv4_address, comment = "Relay master ingest"
  }]
}

resource "hcloud_zone_rrset" "wildcard-relay-nyrox-dev-A-records" {
  zone = data.hcloud_zone.by_name.id
  type = "A"
  name = "*.relay"
  ttl  = 3600

  records = [{
    value = hcloud_server.pangolin-master.ipv4_address, comment = "Relay master ingest"
  }]
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