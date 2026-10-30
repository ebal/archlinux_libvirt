# Settings, edit these
locals {
  project   = "arch"            # Consul state path opentofu/<project>/state
  hostnames = toset(["arch01"]) # One VM per entry
  timezone  = "Europe/Athens"

  gh_user  = "ebal" # Guest user, SSH keys come from github.com/<gh_user>.keys
  ssh_port = 54321

  # Share the local ./logs directory read-only into the guest at /mnt/logs (9p)
  share_logs = false

  # Pass the host CPU through (host-passthrough), exposes vmx/svm for nested KVM
  # false keeps the libvirt default CPU model (qemu64)
  nested_kvm = true

  # Backing cloud image, see README for the download
  cloud_image = "/opt/hashicorp/terraform/libvirt/images/archlinux/Arch-Linux-x86_64-cloudimg.qcow2"

  vol_size = 10 * 1024 * 1024 * 1024 # Disk size, 10G
  vcpu     = 2                       # Virtual CPUs
  vmem     = 4096                    # RAM in MiB
}
