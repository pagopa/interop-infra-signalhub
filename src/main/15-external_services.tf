# aurora rds
data "aws_rds_engine_version" "postgresql" {
  engine  = "aurora-postgresql"
  version = "15.3"
}

module "aurora_postgresql_v2" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "8.5.0"

  name                        = "${local.project}-postgresql"
  database_name               = regex("[[:alnum:]]+", var.app_name)
  engine                      = data.aws_rds_engine_version.postgresql.engine
  engine_version              = data.aws_rds_engine_version.postgresql.version
  engine_mode                 = "provisioned"
  storage_encrypted           = true
  master_username             = "root"
  manage_master_user_password = false
  master_password             = random_password.master.result

  vpc_id                 = module.vpc.vpc_id
  create_db_subnet_group = true
  subnets                = module.vpc.private_subnets

  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }

  monitoring_interval = 60

  apply_immediately   = true
  skip_final_snapshot = true

  serverlessv2_scaling_configuration = {
    min_capacity = var.aurora_rds_cluster_min_capacity
    max_capacity = var.aurora_rds_cluster_max_capacity
  }

  instance_class = "db.serverless"
  instances = {
    one = {}
  }

  tags = merge(var.tags, {
    name = "Aurora RDS Postgresql"
  })
}

resource "random_password" "master" {
  length  = 20
  special = false
}


# amazon sqs
module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 4.0.2"

  name = "${local.project}-internal-queue"

  visibility_timeout_seconds = 43200
  # Dead letter queue
  create_dlq = true

  tags = merge(var.tags, {
    name = "SQS Queue"
  })
}


# elasticache redis
resource "aws_security_group" "redis" {
  name   = "${local.project}-elasticache-redis-sg"
  vpc_id = module.vpc.vpc_id
}

#resource "aws_security_group_rule" "redis_ingress" {
#  type                     = "ingress"
#  from_port                = "6379"
#  to_port                  = "6379"
#  protocol                 = "tcp"
#  source_security_group_id = module.vpc.default_security_group_id
#  security_group_id        = aws_security_group.redis.id
#}

module "redis" {
  source  = "umotif-public/elasticache-redis/aws"
  version = "~> 3.5.0"

  name_prefix        = "${local.project}-redis"
  num_cache_clusters = 2
  node_type          = "cache.t4g.small"

  engine_version           = "7.0"
  port                     = 6379
  maintenance_window       = "mon:03:00-mon:04:00"
  snapshot_window          = "04:00-06:00"
  snapshot_retention_limit = 7

  automatic_failover_enabled = true

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = "1234567890asdfghjkl"

  apply_immediately = true
  family            = "redis7"
  description       = "Elasticache redis"

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]

  parameter = [
    {
      name  = "repl-backlog-size"
      value = "16384"
    }
  ]

  log_delivery_configuration = [
    {
      destination_type = "cloudwatch-logs"
      destination      = "aws_cloudwatch_log_group.example.name"
      log_format       = "json"
      log_type         = "engine-log"
    }
  ]

  #  allowed_security_groups = [aws_security_group.redis.id]

  tags = merge(var.tags, {
    name = "ElastiCache Redis cluster"
  })
}

# TODO bucket s3 per primo import
