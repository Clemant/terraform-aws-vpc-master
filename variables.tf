variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_name" {
  type    = string
 default = "insset"
 description ="Nom de mon VPC"
}

variable "vpc_cibr" {
  type    = string
  /*default = "10.0.0.0/16"*/
  default="172.29.0.0/16"
}

variable "vpc_azs" {
  type    = list(string)
  default=["a","b","c"]
}





