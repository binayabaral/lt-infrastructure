variable "vpc_cidr" {
  type = map(string)
  default = {
    dev  = "10.0.0.0/16"
    prod = "10.1.0.0/16"
  }
}

variable "public_subnet_cidrs" {
  type = map(list(string))
  default = {
    dev  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
    prod = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]
  }
}
