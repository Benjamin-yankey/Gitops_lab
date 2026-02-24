# Use existing key pair - do not generate keys
data "aws_key_pair" "existing" {
  key_name = var.key_name
}