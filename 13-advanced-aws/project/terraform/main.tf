###############################################################################
# HRMS Enterprise Infrastructure — Terraform Root Module
# Phase 13 Capstone Project
###############################################################################

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  backend "s3" {
    bucket         = "hrms-terraform-state-prod"
    key            = "hrms/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "hrms-terraform-lock"
    encrypt        = true
  }
}

###############################################################################
# Providers
###############################################################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "hrms"
      Environment = var.environment
      Team        = var.team
      CostCenter  = var.cost_center
      ManagedBy   = "terraform"
    }
  }
}

# us-east-1 provider for WAF Web ACL + ACM (CloudFront requires global scope)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "hrms"
      Environment = var.environment
      Team        = var.team
      ManagedBy   = "terraform"
    }
  }
}

# DR region provider for Aurora Global replica
provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = {
      Project     = "hrms"
      Environment = var.environment
      Team        = var.team
      ManagedBy   = "terraform"
    }
  }
}

###############################################################################
# Data sources
###############################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# KMS Keys (one per major service)
###############################################################################

resource "aws_kms_key" "rds" {
  description             = "hrms-${var.environment} Aurora encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/hrms-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_kms_key" "s3" {
  description             = "hrms-${var.environment} S3 encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "s3" {
  name          = "alias/hrms-${var.environment}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

resource "aws_kms_key" "sqs" {
  description             = "hrms-${var.environment} SQS encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "sqs" {
  name          = "alias/hrms-${var.environment}-sqs"
  target_key_id = aws_kms_key.sqs.key_id
}

###############################################################################
# VPC
###############################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = { Name = "hrms-${var.environment}-public-${count.index + 1}" }
}

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = { Name = "hrms-${var.environment}-private-${count.index + 1}" }
}

resource "aws_subnet" "data" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = var.availability_zones[count.index]

  tags = { Name = "hrms-${var.environment}-data-${count.index + 1}" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# VPC Endpoints — keeps traffic off the internet
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = aws_route_table.private[*].id
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

###############################################################################
# Security Groups
###############################################################################

resource "aws_security_group" "alb" {
  name        = "hrms-${var.environment}-alb"
  description = "ALB — HTTPS from internet (CloudFront prefix list in production)"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from CloudFront (tighten to CF prefix list in prod)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_api" {
  name        = "hrms-${var.environment}-ecs-api"
  description = "ECS API tasks — only accept traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "App port from ALB only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "aurora" {
  name        = "hrms-${var.environment}-aurora"
  description = "Aurora — accept only from ECS tasks and RDS Proxy"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_api.id, aws_security_group.rds_proxy.id]
    description     = "MySQL from ECS and RDS Proxy"
  }
}

resource "aws_security_group" "rds_proxy" {
  name        = "hrms-${var.environment}-rds-proxy"
  description = "RDS Proxy security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_api.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "elasticache" {
  name        = "hrms-${var.environment}-elasticache"
  description = "ElastiCache Redis — ECS tasks only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_api.id]
    description     = "Redis from ECS tasks only"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "hrms-${var.environment}-vpc-endpoints"
  description = "Interface VPC endpoints (SQS, Secrets Manager, etc.)"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

###############################################################################
# Aurora MySQL Cluster
###############################################################################

resource "aws_db_subnet_group" "aurora" {
  name       = "hrms-${var.environment}-aurora"
  subnet_ids = aws_subnet.data[*].id
}

resource "aws_rds_cluster" "hrms" {
  cluster_identifier = "hrms-${var.environment}"
  engine             = "aurora-mysql"
  engine_version     = "8.0.mysql_aurora.3.05.2"
  database_name      = var.db_name

  # Credentials managed by Secrets Manager rotation — set initial secret separately
  manage_master_user_password = true
  master_username             = "hrms_admin"

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  kms_key_id        = aws_kms_key.rds.arn
  storage_encrypted = true

  backup_retention_period      = var.db_backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  deletion_protection = var.environment == "prod"
  skip_final_snapshot = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "hrms-prod-final-${formatdate("YYYYMMDD", timestamp())}" : null

  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [master_password]
  }
}

resource "aws_rds_cluster_instance" "hrms" {
  count              = var.db_instance_count
  identifier         = "hrms-${var.environment}-${count.index}"
  cluster_identifier = aws_rds_cluster.hrms.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.hrms.engine
  engine_version     = aws_rds_cluster.hrms.engine_version

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  auto_minor_version_upgrade            = true
}

###############################################################################
# RDS Proxy
###############################################################################

resource "aws_db_proxy" "hrms" {
  name                   = "hrms-${var.environment}-proxy"
  debug_logging          = false
  engine_family          = "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [aws_security_group.rds_proxy.id]
  vpc_subnet_ids         = aws_subnet.data[*].id

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_rds_cluster.hrms.master_user_secret[0].secret_arn
  }
}

resource "aws_db_proxy_default_target_group" "hrms" {
  db_proxy_name = aws_db_proxy.hrms.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 90
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "hrms" {
  db_cluster_identifier = aws_rds_cluster.hrms.id
  db_proxy_name         = aws_db_proxy.hrms.name
  target_group_name     = aws_db_proxy_default_target_group.hrms.name
}

resource "aws_iam_role" "rds_proxy" {
  name = "hrms-${var.environment}-rds-proxy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "rds_proxy_secrets" {
  name = "rds-proxy-secrets"
  role = aws_iam_role.rds_proxy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_rds_cluster.hrms.master_user_secret[0].secret_arn
    }]
  })
}

###############################################################################
# ElastiCache Redis (cluster mode)
###############################################################################

resource "aws_elasticache_subnet_group" "hrms" {
  name       = "hrms-${var.environment}-redis"
  subnet_ids = aws_subnet.data[*].id
}

resource "aws_elasticache_parameter_group" "hrms" {
  family = "redis7.x"
  name   = "hrms-${var.environment}-redis"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "lazyfree-lazy-expire"
    value = "yes"
  }
}

resource "aws_elasticache_replication_group" "hrms" {
  replication_group_id = "hrms-${var.environment}"
  description          = "HRMS Redis cluster (cluster mode enabled)"

  node_type          = var.redis_node_type
  num_node_groups    = var.redis_num_shards
  replicas_per_node_group = var.redis_replicas_per_shard

  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name  = aws_elasticache_subnet_group.hrms.name
  security_group_ids = [aws_security_group.elasticache.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result
  auth_token_update_strategy = "ROTATE"

  parameter_group_name = aws_elasticache_parameter_group.hrms.name
  engine_version       = "7.1"

  snapshot_retention_limit = 7
  snapshot_window          = "05:00-06:00"
  maintenance_window       = "sun:06:00-sun:07:00"

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  lifecycle {
    ignore_changes = [auth_token]
  }
}

resource "random_password" "redis_auth" {
  length  = 32
  special = false
}

resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/hrms/${var.environment}/redis/slow-log"
  retention_in_days = 30
}

###############################################################################
# SQS Queues
###############################################################################

locals {
  queues = ["payroll", "leave", "notifications"]
}

resource "aws_sqs_queue" "hrms_dlq" {
  for_each = toset(local.queues)

  name              = "hrms-${var.environment}-${each.key}-dlq"
  kms_master_key_id = aws_kms_key.sqs.id

  message_retention_seconds = 1209600 # 14 days for DLQ inspection
}

resource "aws_sqs_queue" "hrms" {
  for_each = toset(local.queues)

  name                       = "hrms-${var.environment}-${each.key}"
  kms_master_key_id          = aws_kms_key.sqs.id
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 20     # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.hrms_dlq[each.key].arn
    maxReceiveCount     = 3
  })
}

###############################################################################
# SNS Topic (fan-out for HRMS events)
###############################################################################

resource "aws_sns_topic" "hrms_events" {
  name              = "hrms-${var.environment}-events"
  kms_master_key_id = aws_kms_key.sqs.id
}

resource "aws_sns_topic_subscription" "notifications_queue" {
  topic_arn = aws_sns_topic.hrms_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.hrms["notifications"].arn

  filter_policy = jsonencode({
    event_type = ["email", "sms", "push"]
  })
}

###############################################################################
# S3 — Static Assets
###############################################################################

resource "aws_s3_bucket" "static" {
  bucket = "hrms-${var.environment}-static-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket                  = aws_s3_bucket.static.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###############################################################################
# WAF Web ACL (us-east-1 for CloudFront)
###############################################################################

resource "aws_wafv2_web_acl" "hrms" {
  provider = aws.us_east_1
  name     = "hrms-${var.environment}"
  scope    = "CLOUDFRONT"

  default_action { allow {} }

  # 1 — AWS Common Rule Set (OWASP Top 10)
  rule {
    name     = "common-rules"
    priority = 10
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "hrms-common-rules"
    }
  }

  # 2 — SQL injection protection
  rule {
    name     = "sqli-rules"
    priority = 20
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "hrms-sqli-rules"
    }
  }

  # 3 — Rate limit per IP
  rule {
    name     = "rate-limit"
    priority = 30
    action { block {} }
    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "hrms-rate-limit"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "hrms-waf"
  }
}

###############################################################################
# CloudFront
###############################################################################

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "hrms-${var.environment}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "hrms" {
  depends_on = [aws_wafv2_web_acl.hrms]

  web_acl_id = aws_wafv2_web_acl.hrms.arn
  enabled    = true
  aliases    = [var.domain_name]

  # S3 static assets origin
  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "s3-static"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # ALB API origin
  origin {
    domain_name = aws_lb.hrms.dns_name
    origin_id   = "alb-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Static assets behaviour (long TTL, hashed filenames)
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-static"

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # API behaviour (no caching)
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-api"

    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # Managed-AllViewerExceptHostHeader

    viewer_protocol_policy = "redirect-to-https"
  }

  # Default (SPA index.html)
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-static"

    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled for SPA

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # SPA 404 → index.html
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

###############################################################################
# ALB
###############################################################################

resource "aws_lb" "hrms" {
  name               = "hrms-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = var.environment == "prod"
}

resource "aws_lb_target_group" "api" {
  name        = "hrms-${var.environment}-api"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.hrms.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

###############################################################################
# ECS Cluster
###############################################################################

resource "aws_ecs_cluster" "hrms" {
  name = "hrms-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "ecs_api" {
  name              = "/hrms/${var.environment}/ecs/api"
  retention_in_days = 90
}

resource "aws_iam_role" "ecs_task" {
  name = "hrms-${var.environment}-ecs-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "hrms-task-policy"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = [for q in aws_sqs_queue.hrms : q.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.hrms_events.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.static.arn}/uploads/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [aws_kms_key.sqs.arn, aws_kms_key.s3.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "ecs_execution" {
  name = "hrms-${var.environment}-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "api" {
  family                   = "hrms-${var.environment}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_task_cpu
  memory                   = var.api_task_memory
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name  = "hrms-api"
    image = var.ecr_image_uri

    portMappings = [{ containerPort = 3000, protocol = "tcp" }]

    environment = [
      { name = "NODE_ENV", value = var.environment },
      { name = "REDIS_URL", value = "rediss://${aws_elasticache_replication_group.hrms.configuration_endpoint_address}:6379" },
      { name = "DB_PROXY_ENDPOINT", value = aws_db_proxy.hrms.endpoint },
      { name = "SQS_PAYROLL_URL", value = aws_sqs_queue.hrms["payroll"].url },
      { name = "SNS_EVENTS_ARN", value = aws_sns_topic.hrms_events.arn }
    ]

    secrets = [{
      name      = "DB_SECRET_ARN"
      valueFrom = aws_rds_cluster.hrms.master_user_secret[0].secret_arn
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_api.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "api"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
      interval    = 10
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
  }])
}

resource "aws_ecs_service" "api" {
  name            = "hrms-${var.environment}-api"
  cluster         = aws_ecs_cluster.hrms.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_api.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "hrms-api"
    container_port   = 3000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }
}

# Auto-scaling for API service
resource "aws_appautoscaling_target" "api" {
  max_capacity       = var.api_max_capacity
  min_capacity       = var.api_min_capacity
  resource_id        = "service/${aws_ecs_cluster.hrms.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "hrms-${var.environment}-api-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

###############################################################################
# CloudWatch Alarms
###############################################################################

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "hrms-${var.environment}-api-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 5
  alarm_description   = "API 5xx error rate > 5% for 2 consecutive minutes"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "e1"
    expression  = "m2/m1*100"
    label       = "5xx Error Rate %"
    return_data = true
  }

  metric_query {
    id = "m1"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = aws_lb.hrms.arn_suffix }
    }
  }

  metric_query {
    id = "m2"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = aws_lb.hrms.arn_suffix }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "db_connections" {
  alarm_name          = "hrms-${var.environment}-db-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 200
  alarm_description   = "Aurora connection count exceeds 200"
  treat_missing_data  = "notBreaching"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  period              = 60
  statistic           = "Average"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.hrms.id
  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_age" {
  for_each = toset(local.queues)

  alarm_name          = "hrms-${var.environment}-${each.key}-queue-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 300 # 5 minutes
  alarm_description   = "SQS ${each.key} oldest message > 5 minutes — consumers may be stuck"
  treat_missing_data  = "notBreaching"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  period              = 60
  statistic           = "Maximum"

  dimensions = {
    QueueName = aws_sqs_queue.hrms[each.key].name
  }
}

###############################################################################
# Outputs
###############################################################################

output "cloudfront_domain" {
  description = "CloudFront distribution domain (use as CNAME for var.domain_name)"
  value       = aws_cloudfront_distribution.hrms.domain_name
}

output "alb_dns_name" {
  description = "ALB DNS name (internal — accessed through CloudFront)"
  value       = aws_lb.hrms.dns_name
}

output "aurora_cluster_endpoint" {
  description = "Aurora cluster write endpoint (use RDS Proxy in production)"
  value       = aws_rds_cluster.hrms.endpoint
  sensitive   = true
}

output "rds_proxy_endpoint" {
  description = "RDS Proxy endpoint for ECS tasks"
  value       = aws_db_proxy.hrms.endpoint
  sensitive   = true
}

output "redis_configuration_endpoint" {
  description = "ElastiCache Redis cluster configuration endpoint"
  value       = aws_elasticache_replication_group.hrms.configuration_endpoint_address
  sensitive   = true
}

output "sqs_queue_urls" {
  description = "SQS queue URLs by name"
  value       = { for k, q in aws_sqs_queue.hrms : k => q.url }
}

output "sns_events_arn" {
  description = "SNS hrms-events topic ARN"
  value       = aws_sns_topic.hrms_events.arn
}
