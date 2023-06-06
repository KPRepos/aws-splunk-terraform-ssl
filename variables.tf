variable "region" {
  type        = string
  description = "The AWS Region to deploy terraform"
}


variable "vpc_cidr" {
  type        = string
  description = ""
}

variable "env_name" {
  type        = string
  description = "The environment key to append to resources"
}
