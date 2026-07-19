terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "project" {
  type = string
}

variable "vpc" {
  type = any
}

variable "sg" {
  type = any
}
