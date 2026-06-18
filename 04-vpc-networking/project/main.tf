###############################################################################
# main.tf — Production 3-tier VPC (public / app / data) across N AZs
#
# Creates: VPC, IGW, per-AZ public/app/data subnets, one NAT GW per AZ,
#          route tables (public shared, app per-AZ, data isolated),
#          chained security groups (alb -> app -> db), and a free S3 endpoint.
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Discover the AZs available in this Region, take the first az_count of them.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  tags = { Project = var.project, ManagedBy = "terraform" }
}

###############################################################################
# VPC + Internet Gateway
###############################################################################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.project}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "${var.project}-igw" })
}

###############################################################################
# Subnets — one public, one app, one data per AZ (CIDRs derived from VPC CIDR)
###############################################################################
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index * 10)       # .0/24, .10/24
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${var.project}-public-${local.azs[count.index]}", Tier = "public" })
}

resource "aws_subnet" "app" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index * 10 + 1)         # .1/24, .11/24
  tags              = merge(local.tags, { Name = "${var.project}-app-${local.azs[count.index]}", Tier = "app" })
}

resource "aws_subnet" "data" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index * 10 + 2)         # .2/24, .12/24
  tags              = merge(local.tags, { Name = "${var.project}-data-${local.azs[count.index]}", Tier = "data" })
}

###############################################################################
# NAT Gateways — one per AZ (HA + avoids cross-AZ data charges)
###############################################################################
resource "aws_eip" "nat" {
  count  = var.az_count
  domain = "vpc"
  tags   = merge(local.tags, { Name = "${var.project}-nat-eip-${local.azs[count.index]}" })
}

resource "aws_nat_gateway" "nat" {
  count         = var.az_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id   # NAT lives in the public subnet
  tags          = merge(local.tags, { Name = "${var.project}-nat-${local.azs[count.index]}" })
  depends_on    = [aws_internet_gateway.igw]
}

###############################################################################
# Route tables
#   public : one shared table, 0.0.0.0/0 -> IGW
#   app    : one PER AZ, 0.0.0.0/0 -> that AZ's local NAT
#   data   : one shared table, NO internet route (local only)
###############################################################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.tags, { Name = "${var.project}-rt-public" })
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id   # local-AZ NAT
  }
  tags = merge(local.tags, { Name = "${var.project}-rt-app-${local.azs[count.index]}" })
}

resource "aws_route_table_association" "app" {
  count          = var.az_count
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id
  # No 0.0.0.0/0 route — the data tier is isolated (local route only).
  tags = merge(local.tags, { Name = "${var.project}-rt-data" })
}

resource "aws_route_table_association" "data" {
  count          = var.az_count
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

###############################################################################
# S3 Gateway Endpoint (FREE, private) attached to the app route tables
###############################################################################
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.app[*].id
  tags              = merge(local.tags, { Name = "${var.project}-s3-endpoint" })
}

###############################################################################
# Security groups — the chain: ALB(443 from world) -> APP(app_port) -> DB(db_port)
###############################################################################
resource "aws_security_group" "alb" {
  name        = "${var.project}-sg-alb"
  description = "Public load balancer: allow 80/443 from the internet"
  vpc_id      = aws_vpc.main.id
  tags        = merge(local.tags, { Name = "${var.project}-sg-alb" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere (redirect to HTTPS)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all_out" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "app" {
  name        = "${var.project}-sg-app"
  description = "App tier: allow app_port ONLY from the ALB SG"
  vpc_id      = aws_vpc.main.id
  tags        = merge(local.tags, { Name = "${var.project}-sg-app" })
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from the ALB only"
  referenced_security_group_id = aws_security_group.alb.id   # SG CHAINING, not a CIDR
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all_out" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "db" {
  name        = "${var.project}-sg-db"
  description = "Data tier: allow db_port ONLY from the app SG"
  vpc_id      = aws_vpc.main.id
  tags        = merge(local.tags, { Name = "${var.project}-sg-db" })
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "DB port from the app tier only"
  referenced_security_group_id = aws_security_group.app.id   # SG CHAINING
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}
# Note: the data tier deliberately has NO egress rule to the internet beyond
# the VPC; add a scoped egress rule only if your DB engine requires it.
