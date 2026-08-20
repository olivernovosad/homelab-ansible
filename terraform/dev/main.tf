terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
  }
}

# NOTE: local state only, no remote backend/locking configured.
# Acceptable for a single-operator homelab; in a team setting this would move
# to a remote backend (e.g. S3 + DynamoDB lock, or Terraform Cloud) to avoid
# state file conflicts and enable collaboration.

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-24.04-base.qcow2"
  pool   = "default"
  format = "qcow2"

  # Pinned to a specific static release instead of /current/ for reproducibility.
  source = "https://cloud-images.ubuntu.com/releases/24.04/release-20240423/ubuntu-24.04-server-cloudimg-amd64.img"
}

resource "libvirt_volume" "staging_disk" {
  name           = "staging-node-disk.qcow2"
  base_volume_id = libvirt_volume.ubuntu_base.id
  pool           = "default"
  size           = 21474836480 # 20 GB
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name = "commoninit.iso"
  pool = "default"

  user_data = <<-EOT
    #cloud-config
    users:
      - name: ubuntu
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
          - ${file("~/.ssh/id_rsa.pub")}
  EOT

  meta_data = <<-EOT
    instance-id: staging-node-01
    local-hostname: staging-node-01
  EOT
}

resource "libvirt_domain" "staging_node" {
  name   = "staging-node-01"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.staging_disk.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

output "staging_ip" {
  value = libvirt_domain.staging_node.network_interface[0].addresses
}

resource "local_file" "ansible_inventory" {
  content  = <<-EOT
    [staging]
    staging-vm ansible_host=${libvirt_domain.staging_node.network_interface[0].addresses[0]} ansible_user=ubuntu

    [staging:vars]
    # Disables host key checking ONLY for this temporary KVM test VM
    ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
  EOT
  filename = "${path.module}/../../ansible/inventories/dev.ini"
}
