# Example: HCP Terraform (formerly Terraform Cloud) as a Remote Backend.
#
# The modern `cloud` block replaces the older `backend "remote"` block.
terraform {
  cloud {
    organization = "hpi"

    workspaces {
      name = "pro"
    }
  }
}
