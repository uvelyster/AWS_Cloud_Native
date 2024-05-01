
resource "tls_private_key" "test_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "test_keypair" {
  key_name   = "deploy-demo-keypair"
  public_key = tls_private_key.test_key.public_key_openssh
} 

resource "local_file" "test_local" {
  filename        = "./keypair/deploy-demo-keypair.pem"
  content         = tls_private_key.test_key.private_key_pem
  file_permission = "0400"
}
