variable "instance_type" {
  type        = string
  description = "Instance type of the EC2"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "instance_type must be one of: t3.micro, t3.small."
  }
}
