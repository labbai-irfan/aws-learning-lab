variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "Must be prod, staging, or dev."
  }
}

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "Disaster recovery region for Aurora Global Database"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to deploy into (minimum 2 for Multi-AZ, 3 recommended)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# ─── ECS ──────────────────────────────────────────────────────────────────────

variable "ecr_image_uri" {
  description = "Full ECR image URI for the HRMS API (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/hrms-api:abc123)"
  type        = string
}

variable "api_task_cpu" {
  description = "ECS task CPU units for the API service"
  type        = number
  default     = 1024
}

variable "api_task_memory" {
  description = "ECS task memory (MB) for the API service"
  type        = number
  default     = 2048
}

variable "api_desired_count" {
  description = "Desired number of API ECS tasks"
  type        = number
  default     = 2
}

variable "api_min_capacity" {
  description = "Minimum number of API ECS tasks for auto-scaling"
  type        = number
  default     = 2
}

variable "api_max_capacity" {
  description = "Maximum number of API ECS tasks for auto-scaling"
  type        = number
  default     = 20
}

variable "worker_min_capacity" {
  description = "Minimum SQS worker tasks"
  type        = number
  default     = 0
}

variable "worker_max_capacity" {
  description = "Maximum SQS worker tasks"
  type        = number
  default     = 50
}

# ─── Aurora ───────────────────────────────────────────────────────────────────

variable "db_instance_class" {
  description = "Aurora instance class"
  type        = string
  default     = "db.r7g.large"
}

variable "db_instance_count" {
  description = "Number of Aurora instances (1 writer + N-1 readers)"
  type        = number
  default     = 2
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "hrms"
}

variable "db_backup_retention_days" {
  description = "Automated backup retention period (1-35)"
  type        = number
  default     = 35

  validation {
    condition     = var.db_backup_retention_days >= 1 && var.db_backup_retention_days <= 35
    error_message = "Must be between 1 and 35 days."
  }
}

variable "enable_aurora_global" {
  description = "Enable Aurora Global Database for multi-region DR"
  type        = bool
  default     = true
}

# ─── ElastiCache ──────────────────────────────────────────────────────────────

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.r7g.large"
}

variable "redis_num_shards" {
  description = "Number of Redis shards (cluster mode)"
  type        = number
  default     = 3
}

variable "redis_replicas_per_shard" {
  description = "Read replicas per Redis shard"
  type        = number
  default     = 1
}

# ─── CloudFront / WAF ─────────────────────────────────────────────────────────

variable "domain_name" {
  description = "Primary domain name (e.g. hrms.example.com)"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront"
  type        = string
}

variable "waf_rate_limit" {
  description = "Max requests per IP per 5-minute window in WAF"
  type        = number
  default     = 1000
}

# ─── Tagging / meta ───────────────────────────────────────────────────────────

variable "team" {
  description = "Owning team for cost allocation tags"
  type        = string
  default     = "platform"
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
}
