variable "os_version" {
  type        = string
  description = "The version of the operating system to download and install"
}

variable "architecture" {
  type = object({
    name  = string
    image = string
    qemu  = string
  })
  description = "The type of CPU to use when building"
}

variable "machine_type" {
  default     = "q35"
  type        = string
  description = "The type of machine to use when building"
}

variable "cpu_type" {
  default     = "qemu64"
  type        = string
  description = "The type of CPU to use when building"
}

variable "memory" {
  default     = 4096
  type        = number
  description = "The amount of memory to use when building the VM in megabytes"
}

variable "cpus" {
  default     = 2
  type        = number
  description = "The number of cpus to use when building the VM"
}

variable "disk_size" {
  default     = "12G"
  type        = string
  description = "The size in bytes of the hard disk of the VM"
}

variable "checksum" {
  type        = string
  description = "The checksum for the virtual hard drive file"
}

variable "root_password" {
  default     = "runner"
  type        = string
  description = "The password for the root user"
}

variable "secondary_user_username" {
  default     = "runner"
  type        = string
  description = "The name for the secondary user"
}

variable "headless" {
  default     = false
  description = "When this value is set to `true`, the machine will start without a console"
}

variable "use_default_display" {
  default     = true
  type        = bool
  description = "If true, do not pass a -display option to qemu, allowing it to choose the default"
}

variable "display" {
  default     = "cocoa"
  description = "What QEMU -display option to use"
}

locals {
  iso_target_extension = "iso"
  iso_target_path      = "packer_cache"
  iso_full_target_path = "${local.iso_target_path}/${sha1(var.checksum)}.${local.iso_target_extension}"

  image   = "dfly-x86_64-${var.os_version}_REL.${local.iso_target_extension}"
  vm_name = "dragonflybsd-${var.os_version}-${var.architecture.name}.qcow2"
}

source "qemu" "qemu" {
  machine_type = var.machine_type
  cpus         = var.cpus
  memory       = var.memory
  net_device   = "virtio-net"

  disk_compression = true
  disk_interface   = "virtio"
  disk_size        = var.disk_size
  format           = "qcow2"

  headless            = var.headless
  use_default_display = var.use_default_display
  display             = var.display
  accelerator         = "none"
  qemu_binary         = "qemu-system-${var.architecture.qemu}"

  boot_wait = "10s"

  boot_steps = [
    ["<wait90s>", "Wait for live CD to boot and show login prompt"],
    ["root<enter><wait10s>", "Login as root"],
    ["dhclient vtnet0<enter><wait15s>", "Configure network via DHCP"],
    ["fetch -o /tmp/install.sh http://{{.HTTPIP}}:{{.HTTPPort}}/resources/install.sh<enter><wait5s>", "Download install script"],
    ["env DISK='da0' ROOT_PASSWORD='${var.root_password}' sh /tmp/install.sh && reboot<enter><wait5m>", "Run installation and reboot"],
  ]

  ssh_username = "root"
  ssh_password = var.root_password
  ssh_timeout  = "10000s"

  qemuargs = [
    ["-cpu", var.cpu_type],
    ["-boot", "strict=off"],
    ["-monitor", "none"],
    ["-accel", "hvf"],
    ["-accel", "kvm"],
    ["-accel", "tcg"],
    ["-netdev", "user,id=user.0,hostfwd=tcp::{{ .SSHHostPort }}-:22,ipv6=off"],
    ["-device", "virtio-scsi-pci"],
    ["-device", "scsi-hd,drive=drive0,bootindex=0"],
    ["-device", "scsi-cd,drive=drive1,bootindex=1"],
    ["-drive", "if=none,file=output/${local.vm_name},id=drive0,cache=writeback,discard=ignore,format=qcow2"],
    ["-drive", "if=none,file=${local.iso_full_target_path},id=drive1,media=disk,format=raw,readonly=on"],
  ]

  iso_checksum         = var.checksum
  iso_target_extension = local.iso_target_extension
  iso_target_path      = local.iso_target_path
  iso_urls = [
    "https://mirror-master.dragonflybsd.org/iso-images/${local.image}",
    "https://avalon.dragonflybsd.org/iso-images/${local.image}",
  ]

  http_directory    = "."
  output_directory  = "output"
  shutdown_command  = "/sbin/poweroff"
  vm_name           = local.vm_name
}

packer {
  required_plugins {
    qemu = {
      version = "~> 1.0.8"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

build {
  sources = ["qemu.qemu"]

  provisioner "shell" {
    script = "resources/provision.sh"
    environment_vars = [
      "SECONDARY_USER=${var.secondary_user_username}",
    ]
  }

  provisioner "shell" {
    script = "resources/custom.sh"
    environment_vars = [
      "SECONDARY_USER=${var.secondary_user_username}"
    ]
  }
}
