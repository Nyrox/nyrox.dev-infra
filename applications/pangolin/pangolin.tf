
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

variable "network_ip" {
    type = string
    description = "Networked IP"
}

resource "hcloud_volume" "pangolin-data" {
  name              = "pangolin-data"
  size              = 10
  location          = "hel1"
  format            = "ext4"
  delete_protection = true
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
    ip = var.network_ip
  }

  user_data = file("${path.module}/pangolin-init.yaml")
}

resource "hcloud_volume_attachment" "pangolin-data-attachment" {
  volume_id = hcloud_volume.pangolin-data.id
  server_id = hcloud_server.pangolin-master.id

  automount = true
}

resource "terraform_data" "symlink-pangolin-data-volume" {
  triggers_replace = hcloud_server.pangolin-master.id

  provisioner "remote-exec" {
    inline = [
      "sudo ln -s /mnt/HC_Volume_${hcloud_volume_attachment.pangolin-data-attachment.volume_id} /opt/pangolin-data",
      "sudo chown pangolin /opt/pangolin-data"
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
    ttl = 3600

    records = [ {
      value = hcloud_server.pangolin-master.ipv4_address, comment = "Relay master ingest"
    } ]
}

resource "hcloud_zone_rrset" "wildcard-relay-nyrox-dev-A-records" {
    zone = data.hcloud_zone.by_name.id
    type = "A"
    name = "*.relay"
    ttl = 3600

    records = [ {
      value = hcloud_server.pangolin-master.ipv4_address, comment = "Relay master ingest"
    } ]
}