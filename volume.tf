# VM disk, a thin qcow2 overlay of the cloud image
resource "libvirt_volume" "archlinux_image" {
  for_each = local.hostnames

  name     = "${each.key}.qcow2"
  pool     = "default"
  capacity = local.vol_size

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = local.cloud_image
    format = {
      type = "qcow2"
    }
  }
}
