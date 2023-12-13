module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1.2"

  name = "${local.project}-vpc"

  cidr            = var.vpc_cidr
  azs             = var.azs
  public_subnets  = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  private_subnets = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  map_public_ip_on_launch = false

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log                                 = true
  create_flow_log_cloudwatch_iam_role             = true
  create_flow_log_cloudwatch_log_group            = true
  flow_log_cloudwatch_log_group_retention_in_days = 1
  flow_log_cloudwatch_log_group_name_prefix       = "/aws/vpc/${local.project}/"

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}


resource "aws_security_group" "vpc_endpoints_private_sg" {
  description = "Private Lambda SG"
  name        = "${local.project}-vpc-endpoints-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    cidr_blocks = [
      var.vpc_cidr
    ]
  }

  egress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    cidr_blocks = [
      var.vpc_cidr
    ]
  }

  tags = merge({
    Name = "Security Group"
    },
    var.tags
  )
}


module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> v5.1.2"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [aws_security_group.vpc_endpoints_private_sg.id]

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.public_route_table_ids

      tags = {
        Name = "s3-vpc-endpoint"
      }
    }

    sqs = {
      service             = "sqs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags = {
        Name = "sqs-vpc-endpoint"
      }
    }
  }
}


