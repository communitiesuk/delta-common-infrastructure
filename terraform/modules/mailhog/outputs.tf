output "ssh_private_key" {
  value     = tls_private_key.main.private_key_openssh
  sensitive = true
}
