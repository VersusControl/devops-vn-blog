variable "label" {
  description = "Color of this environment: green or blue"
  type        = string
}

variable "app_version" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}
