

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      # Here we use version 1.56.0, this may change in the future
      version = "1.56.0"
    }
  }
}

variable "network_id" {
  type        = number
  description = "Hetzner Network ID to use"
}

variable "forgejo_bucket_access_key" {
    type = string
    description = "minio-compatible forgejo bucket access key"
    sensitive = false
}

variable "forgejo_bucket_secret_key" {
    type = string
    description = "minio-compatible forgejo bucket access key"
    sensitive = true
}

variable "forgejo_bucket_endpoint" {
    type = string
    description = "minion-compatible s3 endpoint"
}



resource "hcloud_volume" "forgejo-data" {
  name              = "forgejo-data"
  size              = 10
  location          = "hel1"
  format            = "ext4"
  delete_protection = true
}

data "cloudinit_config" "forgejo-cloud-init" {
    part {
        content_type = "text/cloud-config"
        filename = "cloud.conf"

        content = yamlencode(
            {
                "write_files": [
                    {
                        "path": "/opt/forgejo-deployment/docker-compose.yml",
                        "content": templatefile("${path.module}/docker-compose.yml", {
                            MINIO_ACCESS_KEY = var.forgejo_bucket_access_key,
                            MINIO_SECRET_ACCESS_KEY = var.forgejo_bucket_secret_key,
                            MINIO_ENDPOINT = var.forgejo_bucket_endpoint
                        })
                    }
                ],
                "package_update": true,
                "groups": ["docker"],
                "packages": ["docker.io", "docker-compose"],
                "users": [
                    {
                        "name": "forgejo",
                        "ssh-authorized-keys": [
                            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCpBuzFghRM6bdzirdZzSH9cvC34Rl3Xv7m+kJbtJggyeAzHciXm9suL9ucWPU8zvjnE7mdRcPcN1ypvQute0n/Cmt1wCcOhJqM9nLMsxt0h6y5W4kpRMlSq45aNKg5xVz3EOUdZZoPt5u14BQzo21+ExzZgH3cELlIPvY/nYBBJoZV5tCn6VYs9jWniXb/q7S7cKUninKOZFfiv1j/D38+VsPj51D8WM9tFd5CTplBVUrBsiBwON5CQMvOkkfb7xUxgiDcrIGk5Xgg1VKO4pDqhh8N+E0q8MQJsi+dKd7YJSMKuMWy/AShZQRURVi5wcuVYd91bHHyzZHjRzP/b1CrxjoE94Il4s6yskfV/zN+3famBWld4wvaR/4ab2acWT9eE8DjOSZkYUsN2WaNrZCZDHrShXAewN96cdX3JDWAV2EI9fSrMA45S/13ofpDyR4No1Rzhlpf/I5UwfC8WVuDXXHKOBBwf5bM3cgT8EivU40miorfj8ZMsF/lMBcTm0s= marko@DESKTOP-Q8CO3NO",
                            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/8YwmkuOgTusH2v7azjCppIf7D1h9L43ok68BvQJ0J mark.junge@criipto.com",
                            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKCuumXfIEyIWnlfww3nJ72VmXg36eH2dCB7jBu4hcvH K8S Worker Node Key"
                        ],
                        "sudo": "ALL=(ALL) NOPASSWD:ALL",
                        "shell": "/bin/bash",
                    }
                ],
                "runcmd": [
                    "usermod -aG docker forgejo",
                    "chown forgejo /opt/forgejo-deployment"
                ]
            }
        )
    }
}



resource "hcloud_server" "forgejo-master" {
  name        = "forgejo-master"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "hel1"

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = var.network_id
  }

  user_data = data.cloudinit_config.forgejo-cloud-init.rendered
}

resource "hcloud_volume_attachment" "forgejo-data-attachment" {
    volume_id = hcloud_volume.forgejo-data.id
    server_id = hcloud_server.forgejo-master.id

    automount = true
}

resource "terraform_data" "symlink-forgejo-data-volume" {
  triggers_replace = hcloud_server.forgejo-master.id

  provisioner "remote-exec" {
    inline = [
      "sudo ln -s /mnt/HC_Volume_${hcloud_volume_attachment.forgejo-data-attachment.volume_id} /opt/forgejo-data",
      "sudo chown forgejo /opt/forgejo-data",
      // this is a no-op, but there is some timing issues with cloud-init this resolves
      "sudo apt install docker-compose",
      "cd /opt/forgejo-deployment && docker-compose up -d"
    ]

    connection {
      type        = "ssh"
      user        = "forgejo"
      private_key = file("~/.ssh/id_ed25519.dev-k8s")
      host        = hcloud_server.forgejo-master.ipv4_address
    }
  }
}


/// -- DNS

data "hcloud_zone" "by_name" {
    name = "nyrox.dev"
}

resource "hcloud_zone_rrset" "git-nyrox-dev-A-records" {
    zone = data.hcloud_zone.by_name.id
    type = "A"
    name = "git"
    ttl = 3600

    records = [ {
      value = hcloud_server.forgejo-master.ipv4_address, comment = "Git master address"
    } ]
}


/// - FIREWALL

