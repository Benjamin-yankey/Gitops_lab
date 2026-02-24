output "key_name" {
  description = "Name of the generated key pair"
  value       = aws_key_pair.generated.key_name
}

output "private_key_pem" {
  description = "Generated private key in PEM format"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}

output "public_key_openssh" {
  description = "Generated public key in OpenSSH format"
  value       = tls_private_key.ssh_key.public_key_openssh
}

output "private_key_path" {
  description = "Local filesystem path of generated private key"
  value       = local_sensitive_file.private_key_pem.filename
}

output "public_key_path" {
  description = "Local filesystem path of generated public key"
  value       = local_file.public_key_openssh.filename
}
