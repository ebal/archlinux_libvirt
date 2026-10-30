# One VM per hostname
resource "libvirt_domain" "vm" {
  for_each = local.hostnames

  name        = each.key
  memory      = local.vmem
  memory_unit = "MiB"
  vcpu        = local.vcpu
  type        = "kvm"

  running   = true
  autostart = true # Start on host boot

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [{ dev = "hd" }]
  }

  features = {
    acpi = true
    apic = {}
  }

  # Optional host CPU passthrough for nested KVM, see nested_kvm in locals.tf
  cpu = local.nested_kvm ? {
    mode = "host-passthrough"
  } : null

  devices = {
    # Optional read-only 9p share of ./logs, mounted in the guest at /mnt/logs
    filesystems = local.share_logs ? [{
      source      = { mount = { dir = abspath("${path.module}/logs") } }
      target      = { dir = "shared" }
      access_mode = "mapped"
      read_only   = true
    }] : null

    disks = [{
      source = {
        volume = {
          pool   = "default"
          volume = libvirt_volume.archlinux_image[each.key].name
        }
      }
      target = {
        dev = "vda"
        bus = "virtio"
      }
      driver = {
        name = "qemu"
        type = "qcow2"
      }
      },
      {
        device = "cdrom"
        source = {
          file = {
            file = libvirt_volume.cloudinit[each.key].path
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]

    consoles = [{
      type = "pty"
      target = {
        type = "serial"
      }
      },
      {
        type = "pty"
        target = {
          type = "virtio"
        }
      },
    ]

    channels = [
      {
        source = {
          unix = {}
        }
        target = {
          virt_io = {
            name = "org.qemu.guest_agent.0"
          }
        }
      }
    ]

    interfaces = [{
      model = {
        type = "virtio"
      }
      source = {
        network = {
          network = "default"
        }
      }
      # Block apply until the interface gets a DHCP lease
      wait_for_ip = {
        timeout = 300     # seconds
        source  = "lease" # or "agent" or "any"
      }
    }]

  }

}
