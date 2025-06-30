resource "proxmox_vm_qemu" "k8s-m1" {
  vmid        = 203020
  name        = "k8s-m1"
  target_node = var.node
  agent       = 1
  cores       = 4
  memory      = 4096
  boot        = "order=scsi0"
  clone       = "ubuntu-24.04-ci-template"
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml"
  ciupgrade  = true
  nameserver = "1.1.1.1 8.8.8.8"
  ipconfig0  = "ip=203.0.113.20/24,gw=203.0.113.254"
  skip_ipv6  = true
  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = var.ci_ssh_keys

  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.vm_storage
          size    = "20G" 
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = var.vm_storage
        }
      }
    }
  }

  network {
    id = 0
    bridge = "vmbr2"
    model  = "virtio"
  }
}

resource "proxmox_vm_qemu" "k8s-w1" {
  vmid        = 203021
  name        = "k8s-w1"
  target_node = var.node
  agent       = 1
  cores       = 4
  memory      = 8192
  boot        = "order=scsi0"
  clone       = "ubuntu-24.04-ci-template"
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml"
  ciupgrade  = true
  nameserver = "1.1.1.1 8.8.8.8"
  ipconfig0  = "ip=203.0.113.21/24,gw=203.0.113.254"
  skip_ipv6  = true
  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = var.ci_ssh_keys

  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.vm_storage
          size    = "50G" 
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = var.vm_storage
        }
      }
    }
  }

  network {
    id = 0
    bridge = "vmbr2"
    model  = "virtio"
  }
}