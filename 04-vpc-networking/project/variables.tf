###############################################################################
# variables.tf — tweak these to customize the network
###############################################################################

variable "region" {
  description = "AWS Region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Name prefix applied to every resource tag"
  type        = string
  default     = "vpc-capstone"
}

variable "vpc_cidr" {
  description = "Primary CIDR block for the VPC (/16 gives 65k addresses)"
  type        = string
  default     = "10.0.0.0/16"
}

# Number of Availability Zones to span. 2 = HA baseline, 3 = max resilience.
variable "az_count" {
  description = "How many AZs to spread the tiers across (2 or 3)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 for this capstone."
  }
}

# Per-tier subnet CIDRs are derived from the VPC CIDR with cidrsubnet() in main.tf,
# so you only set the VPC CIDR above. The newbits/offset scheme used there:
#   public  subnet i -> cidrsubnet(vpc_cidr, 8, i)        e.g. 10.0.0.0/24, 10.0.10.0/24...
#   app     subnet i -> cidrsubnet(vpc_cidr, 8, i + 1)    e.g. 10.0.1.0/24, 10.0.11.0/24...
#   data    subnet i -> cidrsubnet(vpc_cidr, 8, i + 2)    e.g. 10.0.2.0/24, 10.0.12.0/24...
# (offset of 10 per AZ keeps tiers visually grouped per AZ)

variable "app_port" {
  description = "Port the app tier listens on (allowed only from the ALB SG)"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port the data tier listens on (allowed only from the app SG)"
  type        = number
  default     = 3306
}
