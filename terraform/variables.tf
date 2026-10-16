variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "key_name" {
  type    = string
  default = "travelmemory-key"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_id" {
  type = string
}

variable "admin_cidr" {
  description = "Administrator public IPv4 CIDR for SSH"
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "172.31.0.0/16"
}

variable "app_subnet_a_cidr" {
  type    = string
  default = "172.31.48.0/20"
}

variable "app_subnet_c_cidr" {
  type    = string
  default = "172.31.64.0/20"
}

variable "database_subnet_cidr" {
  type    = string
  default = "172.31.80.0/20"
}
