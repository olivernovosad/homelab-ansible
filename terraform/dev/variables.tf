
variable "ssh_public_key_path" {
  description = "Path to the SSH public key injected into the staging VM"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
