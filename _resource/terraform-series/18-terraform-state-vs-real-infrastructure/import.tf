# Modern, config-driven import (Terraform 1.5+).
#
# Instead of the imperative `terraform import aws_security_group.allow_http <id>`
# command, declare an `import` block. Terraform performs the import on the next
# `terraform apply`, and the block lives in version control so the import is
# reviewable and repeatable.
#
# Bonus: `terraform plan -generate-config-out=generated.tf` will scaffold the
# resource configuration for you — so the old claim that "everything has to be
# done by hand" no longer holds.
#
# Remove this block once the resource has been imported into state.
import {
  to = aws_security_group.allow_http
  id = "sg-026401f9c4e93a37a"
}
