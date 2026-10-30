# Optional password hash for the console login of gh_user (SSH stays key-only)
# Generate with: openssl passwd -6 'yourpassword'
# Set it outside git, eg. in tofu.config: export TF_VAR_password_hash='$6$...'
variable "password_hash" {
  description = "SHA-512 crypt hash for gh_user console login, empty keeps the password locked"
  type        = string
  default     = ""
  sensitive   = true
}

# Consul agent for the state backend, see provider.tf
# Set it outside git, eg. in tofu.config: export TF_VAR_consul_address='consul.lan:8500'
variable "consul_address" {
  description = "Consul agent address (host:port) for the remote state backend"
  type        = string
  default     = "consul.example.com:8500"
}
