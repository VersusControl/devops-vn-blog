data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "aws-gcp"
  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# The AWS Customer Gateway points at the GCP external IP.
resource "aws_customer_gateway" "gcp_customer_gateway" {
  bgp_asn    = 65000
  ip_address = google_compute_address.aws_customer_gateway.address
  type       = "ipsec.1"

  tags = {
    Name = "gcp-customer-gateway"
  }
}

resource "aws_vpn_gateway" "aws_gcp" {
  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "AWS-GCP"
  }
}

resource "aws_vpn_connection" "aws_gcp" {
  customer_gateway_id = aws_customer_gateway.gcp_customer_gateway.id
  vpn_gateway_id      = aws_vpn_gateway.aws_gcp.id
  type                = "ipsec.1"
  static_routes_only  = true
}

resource "aws_vpn_connection_route" "office" {
  destination_cidr_block = "10.168.0.0/20" # fixed CIDR of the GCP us-west2 region
  vpn_connection_id      = aws_vpn_connection.aws_gcp.id
}
