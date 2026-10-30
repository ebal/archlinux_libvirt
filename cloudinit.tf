# Fetch SSH public keys from GitHub at plan time
# (Arch Linux has no ssh-import-id, so cloud-init cannot do it in the guest)
data "http" "gh_keys" {
  url = "https://github.com/${local.gh_user}.keys"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && trimspace(self.response_body) != ""
      error_message = "Could not fetch any SSH public key for GitHub user ${local.gh_user}."
    }
  }
}

resource "libvirt_cloudinit_disk" "init" {
  for_each = local.hostnames

  name = "cloud-init-${each.key}"
  user_data = templatefile("${path.module}/templates/user-data.yml", {
    hostname      = each.key
    sshdport      = local.ssh_port
    timezone      = local.timezone
    gh_user       = local.gh_user
    ssh_keys      = jsonencode(compact(split("\n", trimspace(data.http.gh_keys.response_body))))
    password_hash = var.password_hash
    share_logs    = local.share_logs
    sshd_config = indent(6, templatefile("${path.module}/templates/sshd_config", {
      gh_user  = local.gh_user
      sshdport = local.ssh_port
    }))
    cleanup = indent(6, file("${path.module}/templates/cleanup.sh"))
  })

  meta_data = yamlencode({
    instance-id    = each.key
    local-hostname = each.key
  })

  network_config = file("${path.module}/templates/netplan.yml")
}

# Upload the cloud-init ISO to the pool, attached to the domain as a cdrom
resource "libvirt_volume" "cloudinit" {
  for_each = local.hostnames

  name = "${each.key}-cloudinit.iso"
  pool = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.init[each.key].path
    }
  }
}
