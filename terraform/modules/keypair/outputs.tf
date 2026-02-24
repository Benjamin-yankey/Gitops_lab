output "key_name" {
  description = "Name of the existing key pair"
  value       = data.aws_key_pair.existing.key_name
}