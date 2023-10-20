module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.17.2"

  cluster_name                    = "${local.project}-eks"
  cluster_version                 = var.cluster_version
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  cluster_enabled_log_types = ["api", "authenticator", "audit", "scheduler", "controllerManager"]

  cluster_addons = {
    kube-proxy = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }
    vpc-cni = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"

      configuration_values = jsonencode({
        env = {
          ENABLE_POD_ENI = "true"
        }
      })
    }
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_cluster_security_group = false
  create_node_security_group    = false

  fargate_profiles = merge(
    { for i in range(3) :
      "${local.project}-${element(split("-", var.azs[i]), 2)}" => {
        selectors  = [{ namespace = "*" }]
        subnet_ids = [element(module.vpc.private_subnets, i)]
      }
    },
    { for i in range(3) :
      "kube-system-${element(split("-", var.azs[i]), 2)}" => {
        selectors  = [{ namespace = "kube-system" }]
        subnet_ids = [element(module.vpc.private_subnets, i)]
      }
    }
  )

  kms_key_administrators = [data.aws_caller_identity.current.arn, data.aws_iam_role.github_action.arn]
  #  kms_key_service_users  = var.kms_auth.services
  #  kms_key_users          = var.kms_auth.users
  #
  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = module.eks_admins_iam_role.iam_role_arn
      username = module.eks_admins_iam_role.iam_role_name
      groups   = ["system:masters"]
    },
  ]

  node_security_group_additional_rules = {
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
  }
}

data "aws_iam_role" "github_action" {
  name = "GitHubActionIACRole"
}

module "allow_eks_access_iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.30.0"

  name          = "allow-eks-access"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

module "eks_admins_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.30.0"

  role_name         = "eks-admin-role"
  create_role       = true
  role_requires_mfa = false

  custom_role_policy_arns = [module.allow_eks_access_iam_policy.arn]

  trusted_role_arns = [
    "arn:aws:iam::${module.vpc.vpc_owner_id}:root"
  ]
}

module "allow_assume_eks_admins_iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.30.0"

  name          = "allow-assume-eks-admin-iam-role"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Effect   = "Allow"
        Resource = module.eks_admins_iam_role.iam_role_arn
      },
    ]
  })
}

#module "eks_admins_iam_group" {
#  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
#  version = "5.30.0"
#
#  name                              = "eks-admin"
#  attach_iam_self_management_policy = false
#  create_group                      = true
#  group_users                       = var.iam_users
#  custom_group_policy_arns          = [module.allow_assume_eks_admins_iam_policy.arn]
#}

#module "eks_admins_iam_group_signal_hub_developers"  {
#  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
#  version = "5.30.0"
#
#  name                              = "SignalHubDevelopers"
#  attach_iam_self_management_policy = false
#  custom_group_policy_arns          = [module.allow_assume_eks_admins_iam_policy.arn]
#}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

# AWS Load Balancer
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

module "aws_load_balancer_controller_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.helm_aws_load_balancer_version

  set {
    name  = "replicaCount"
    value = 1
  }

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_role.iam_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
}

resource "helm_release" "reloader" {
  name       = "reloader"
  repository = "https://stakater.github.io/stakater-charts"
  chart      = "reloader"
  version    = var.helm_reloader_version
  namespace  = kubernetes_namespace.monitoring.id


  set {
    name  = "reloader.watchGlobally"
    value = "false"
  }

  set {
    name  = "namespace"
    value = var.namespace
  }
}