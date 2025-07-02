output "master_ips" {
  value = [
    for vm in proxmox_vm_qemu.k8s_masters : vm.default_ipv4_address
  ]
}

output "worker_ips" {
  value = [
    for vm in proxmox_vm_qemu.k8s_workers : vm.default_ipv4_address
  ]
}