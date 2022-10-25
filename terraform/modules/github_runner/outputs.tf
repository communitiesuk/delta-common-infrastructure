output "instance_ip" {
  value = aws_instance.gh_runner.private_ip
}

output "private_key" {
  value     = tls_private_key.gh_runner_ssh.private_key_openssh
  sensitive = true
}