# OpenTofu + libvirt (dmacvicar/libvirt v0.9.9) - Arch Linux

Provision one or more [Arch Linux cloud image](https://gitlab.archlinux.org/archlinux/arch-boxes) VMs on a local KVM/QEMU host using [OpenTofu](https://opentofu.org/) and the [`dmacvicar/libvirt`](https://github.com/dmacvicar/terraform-provider-libvirt) provider `0.9.9`.
Each VM boots from a thin qcow2 overlay of the cloud image and is configured on first boot by [cloud-init](https://cloudinit.readthedocs.io/): your GitHub SSH keys, a hardened `sshd` on a custom port, base packages, a full system upgrade and a final reboot.

### Features

- Cloud-init bootstrap from a single template, `templates/user-data.yml`
- SSH public keys fetched from `https://github.com/<gh_user>.keys` at plan time (Arch has no `ssh-import-id`)
- Hardened `sshd_config`, key-only login, custom SSH port
- Optional console password, kept out of git as a sensitive variable
- `q35` machine, virtio disk/NIC, serial + virtio consoles, QEMU guest agent channel
- Apply waits for the DHCP lease and prints a ready-to-use `ssh` command
- Optional read-only 9p share of the local `./logs` directory
- Remote state in Consul (opinionated, easy to switch to local state)

![Demo](opentofu-libvirt.gif)

## Installation

### Requirements

- Linux host with KVM/QEMU and libvirt running
- Access to the `qemu:///system` URI
- [OpenTofu](https://opentofu.org/) >= 1.11 (the helper scripts call `tofu`)
- libvirt network `default` (with DHCP) and storage pool `default`
- Internet access from the host (GitHub keys) and the guest (package upgrade)
- Optional: a Consul agent for the state backend (see [State backend](#state-backend))
- The Arch Linux cloud image, downloaded to the path set in `locals.tf`:

```bash
mkdir -p /opt/hashicorp/terraform/libvirt/images/archlinux
curl -L -o /opt/hashicorp/terraform/libvirt/images/archlinux/Arch-Linux-x86_64-cloudimg.qcow2 \
  https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2
```

### Configuration

Review the settings in `locals.tf`:

| Local                | Default                       | Purpose                                              |
| -------------------- | ----------------------------- | ---------------------------------------------------- |
| `project`            | `arch`                        | Consul state path `opentofu/<project>/state`         |
| `hostnames`          | `["arch01"]`                  | One VM per entry                                     |
| `timezone`           | `Europe/Athens`               | Guest timezone                                       |
| `gh_user`            | `ebal`                        | Guest user name and GitHub account for SSH keys      |
| `ssh_port`           | `54321`                       | `sshd` listening port                                |
| `share_logs`         | `false`                       | Share `./logs` read-only at `/mnt/logs` in the guest |
| `nested_kvm`         | `true`                        | Host CPU passthrough, enables nested KVM in the guest |
| `cloud_image`        | `.../Arch-Linux-x86_64-cloudimg.qcow2` | Backing image path                          |
| `vol_size`           | `10G`                         | VM disk size                                         |
| `vcpu` / `vmem`      | `2` / `4096` MiB              | VM CPUs and memory                                   |

To allow a console (not SSH) password for `gh_user`, put the hash in a git-ignored `tofu.config`, which both helper scripts source:

```bash
openssl passwd -6 'yourpassword'
echo "export TF_VAR_password_hash='\$6\$...'" >> tofu.config
```

## Usage

Create the VMs:

```bash
./autostart.sh
```

This runs `tofu init` (only until the backend is configured), `fmt`, `validate`, `plan` and `apply`, and stops at the first step that fails. The apply blocks until each VM has a DHCP lease, then prints:

```
Outputs:

network_interface = {
  "arch01" = "ssh 192.168.122.42 -p 54321"
}
```

cloud-init keeps working after that (package upgrade) and finally reboots the guest, so give it a minute before connecting. Check progress on the serial console:

```bash
sudo virsh console arch01
```

Show the SSH command again at any time:

```bash
tofu output network_interface
```

Destroy everything:

```bash
./destroy.sh
```

This runs `tofu destroy -auto-approve` and removes the local `.terraform/` directory and `tofu.out` plan file. The tracked `.terraform.lock.hcl` stays.

### Templates

| Template        | What it does                                                                     |
| --------------- | -------------------------------------------------------------------------------- |
| `user-data.yml` | Full setup: keys, hardened sshd, packages, upgrade, `/etc/motd`, cleanup, reboot |

The template also uses:

- `templates/sshd_config` - hardened OpenSSH config, `AllowUsers <gh_user>`
- `templates/cleanup.sh` - removes orphan packages and the pacman cache, then disables cloud-init
- `templates/netplan.yml` - cloud-init network v2, DHCP on `eth0` (the Arch cloud image boots with `net.ifnames=0`)

### Repository structure

- `provider.tf` - OpenTofu requirements, providers, Consul backend
- `variables.tf` - the `password_hash` and `consul_address` variables
- `locals.tf` - the settings you edit
- `volume.tf` - VM disk backed by the cloud image
- `cloudinit.tf` - GitHub keys lookup, cloud-init disk and the ISO volume attached to the domain
- `domain.tf` - libvirt domain (disks, NIC, consoles, guest agent channel, optional 9p share)
- `output.tf` - DHCP lease lookup and SSH command output
- `templates/` - cloud-init and supporting templates
- `autostart.sh` / `destroy.sh` - helper scripts
- `.terraform.lock.hcl` - pinned provider versions and checksums

## State backend

Storing state in Consul is an opinionated choice of this project, not a requirement. `provider.tf` uses:

```hcl
backend "consul" {
  address = var.consul_address
  scheme  = "http"
  path    = "opentofu/${local.project}/state"
}
```

OpenTofu (>= 1.8) evaluates the variable at `tofu init`. The default `consul.example.com:8500` is a placeholder, so set your agent in the git-ignored `tofu.config`, which `autostart.sh` sources before `tofu init`:

```bash
echo "export TF_VAR_consul_address='consul.lan:8500'" >> tofu.config
```

To keep the state in a local `terraform.tfstate` file instead, delete the `backend "consul"` block before the first `tofu init`. The file is git-ignored.

The state holds the rendered cloud-init user-data, including the password hash if you set it, so keep Consul on a trusted network or switch to `https`.

## Troubleshooting

- VM not starting:
  - verify `cloud_image` in `locals.tf`
  - check volumes with `virsh -c qemu:///system vol-list default`
  - inspect `virsh -c qemu:///system list --all` and the libvirt logs
- Apply times out waiting for an IP:
  - make sure the `default` network is active and serves DHCP
  - keep the interface named `eth0` in `templates/netplan.yml`: cloud-init renders it for systemd-networkd, which ignores `match: name:` globs and uses the key as the interface name
  - raise `wait_for_ip.timeout` in `domain.tf`
  - on a timeout the provider deletes the domain, so there is nothing left to inspect. To debug, remove the `wait_for_ip` block from `domain.tf`, set a console password (see [Configuration](#configuration)), and watch `sudo virsh console <vm>`
- Cloud-init issues:
  - set `TF_VAR_password_hash` (see [Configuration](#configuration)) and log in as `gh_user` on `sudo virsh console <vm>`
  - read `/var/log/cloud-init.log` and `/var/log/cloud-init-output.log`; `cleanup.sh` wipes them at the end, so comment out `/root/cleanup.sh` in `runcmd` while you debug
- `Could not fetch any SSH public key`: the GitHub user has no public keys or GitHub is unreachable

## Contributing

Pull requests are welcome. Run `tofu fmt -recursive`, `tofu validate` and `shellcheck *.sh templates/*.sh` before submitting.

## License

[GPL-2.0](./LICENSE)
