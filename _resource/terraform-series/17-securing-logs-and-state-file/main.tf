terraform {
  required_version = ">= 1.9"
}

variable "postgres_username" {
  type      = string
  sensitive = true
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

# terraform_data is the built-in replacement for the old `null_resource`
# (no external "null" provider needed). Because the variables above are marked
# sensitive, Terraform suppresses their values in the plan/apply output.
resource "terraform_data" "print" {
  provisioner "local-exec" {
    command = <<-EOF
      echo "username = ${var.postgres_username}"
      echo "password = ${var.postgres_password}"
    EOF
  }
}
