locals {
  env = terraform.workspace
  tags = {
    Creator   = "Binaya Baral"
    Project   = "Laudio"
    Name      = "Leaptalk demo"
    Deletable = "false"
  }
}
