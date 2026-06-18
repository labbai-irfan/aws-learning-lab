###############################################################################
# outputs.tf — values you'll reference when launching workloads into this VPC
###############################################################################

output "vpc_id" {
  description = "The VPC id"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet ids (place ALB / NAT here)"
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "App subnet ids (place app servers / ASG here)"
  value       = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  description = "Data subnet ids (place RDS / cache here)"
  value       = aws_subnet.data[*].id
}

output "nat_public_ips" {
  description = "Elastic IPs of the NAT gateways (the source IP for app egress)"
  value       = aws_eip.nat[*].public_ip
}

output "alb_sg_id" {
  description = "Security group for the public load balancer"
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "Security group for the app tier"
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "Security group for the data tier"
  value       = aws_security_group.db.id
}

output "s3_endpoint_id" {
  description = "The free S3 gateway endpoint"
  value       = aws_vpc_endpoint.s3.id
}
