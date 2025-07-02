variable "proxmox_api_url" {
    default = "https://10.100.0.29:8006/api2/json"
}
variable "proxmox_user" {
    default = "terraform@pve"
}
variable "proxmox_password" {
    default = "4w68crJeLTYeGnW"
}
variable "node" {
  default = "proxds01"
}
variable "template" {
  default = "ubuntu-24.04-ci-template"
}
variable "vm_storage" {
  default = "local-ssd"
}

variable "ciuser" {
    default = "root"      
}

variable "cipassword" {
    default = "password"
}

variable ci_ssh_keys {
    default = "sssh-ed25519 ...."
}

variable "master_count" {
    default = 1
    type = number 
}

variable "worker_count" {
    default = 1
    type = number 

}