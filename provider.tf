terraform {
  required_version = ">= 1.11"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.9"
    }

    # Fetch SSH public keys from GitHub
    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
    }
  }

  # Opinionated: remote state in Consul. Set the address in the git-ignored
  # tofu.config (export TF_VAR_consul_address=host:8500), or remove this
  # block to keep the state in a local terraform.tfstate file.
  backend "consul" {
    address = var.consul_address
    scheme  = "http"
    path    = "opentofu/${local.project}/state"
  }
}

provider "libvirt" {
  # Local system daemon
  uri = "qemu:///system"
  # SSH transport, respects your ~/.ssh/config
  # uri = "qemu+sshcmd://homepc/system"
}
