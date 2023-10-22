resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

#resource "kubernetes_secret" "image_pull_secret" {
#  metadata {
#    name      = "image-pull-secret"
#    namespace = var.namespace
#  }
#
#  type = "kubernetes.io/dockerconfigjson"
#
#  data = {
#    ".dockerconfigjson" = jsonencode({
#      auths = {
#        "https://${var.registry_server}" = {
#          "username" = var.registry_username
#          "password" = var.registry_password
#          "email"    = var.registry_email
#          "auth"     = base64encode("${var.registry_username}:${var.registry_password}")
#        }
#      }
#    })
#  }
#}

resource "aws_kms_key" "interop_client_key" {
  description             = "KMS key for Interop API"
  deletion_window_in_days = 30
  customer_master_key_spec = "RSA_2048"
  key_usage = "ENCRYPT_DECRYPT"
}

resource "aws_kms_key_policy" "example" {
  key_id = aws_kms_key.interop_client_key.id
  policy = jsonencode({
    Id = "example"
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }

        Resource = "*"
        Sid      = "Enable IAM User Permissions"
      },
    ]
    Version = "2012-10-17"
  })
}

data "aws_iam_policy_document" "kms_sqs_access" {

  statement {
    sid = "AllowSQSUse"
    effect = "Allow"
    actions = [
      "sqs:*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid = "AllowKMSUse"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = [
      aws_kms_key.interop_client_key.arn
    ]
  }
}

resource "aws_iam_policy" "kms_sqs_access" {
  name        = "kmsuse"
  description = "Policy to allow use of KMS Key"
  policy      = "${data.aws_iam_policy_document.kms_sqs_access.json}"
}


module "sqs_access" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${local.project}-serviceaccount-role"

  role_policy_arns = {
    policy = aws_iam_policy.kms_sqs_access.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.app_name}"]
    }
  }
}

resource "kubernetes_service_account" "sqs_access" {
  metadata {
    name      = var.app_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.sqs_access.iam_role_arn
    }
  }
}


resource "helm_release" "signalhub" {
  name       = var.app_name
  namespace  = kubernetes_namespace.namespace.id
  repository = "${path.module}/assets/charts"
  chart      = "signalhub-chart"
  version    = "1.0.0"

  values = ["${file("assets/charts/signalhub-chart/configuration_values.yaml")}"]

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.sqs_access.metadata.0.name
  }

  set {
    name  = "image.securityGroupIds[0]"
    value = module.vpc.default_security_group_id
  }

  #  set {
  #    name  = "imagePullSecret"
  #    value = kubernetes_secret.image_pull_secret.metadata.0.name
  #  }

  set {
    name  = "image.repository"
    value = var.registry_server
  }

  set {
    name  = "image.tag"
    value = var.app_version
  }

  set {
    name  = "env.AWS_SQS_ENDPOINT"
    value = replace(module.sqs.queue_url, "${local.project}-internal-queue", "")
  }

  set {
    name  = "env.AWS_INTERNALQUEUENAME"
    value = "${local.project}-internal-queue"
  }

  set {
    name  = "env.MANAGEMENT_ENDPOINTHEALTH_PROBES_ENABLED"
    value = "true"
  }

  set {
    name  = "env.MANAGEMENT_ENDPOINT_HEALTH_SHOWDETAILS"
    value = "always"
  }

  set {
    name  = "apiServiceFqdn"
    value = "api.${var.environment}.signalhub.interop.pagopa.it"
  }

  set {
    name  = "env.SPRING_REDIS_HOST"
    value = module.redis.elasticache_replication_group_primary_endpoint_address
  }

  set {
    name  = "env.SPRING_REDIS_PORT"
    value = module.redis.elasticache_port
  }

  set {
    name  = "env.DATABASE_NAME"
    value = module.aurora_postgresql_v2.cluster_database_name
  }

  set {
    name  = "env.DATABASE_READER_HOST"
    value = module.aurora_postgresql_v2.cluster_reader_endpoint
  }

  set {
    name  = "env.DATABASE_WRITER_HOST"
    value = module.aurora_postgresql_v2.cluster_endpoint
  }

  set {
    name  = "env.DATABASE_PORT"
    value = module.aurora_postgresql_v2.cluster_port
  }

  set {
    name  = "env.DATABASE_USERNAME"
    value = module.aurora_postgresql_v2.cluster_master_username
  }

  set_sensitive {
    name  = "env.DATABASE_PASSWORD"
    value = random_password.master.result
  }

  set {
    name  = "env.PDND_CLIENT_ENDPOINT-URL"
    value = var.pdnd_api_endpoint
  }

  set {
    name  = "env.SECURITY_PAGOPAPROVIDER_CLIENTID"
    value = var.pdnd_auth_client_id
  }

  set {
    name  = "env.SECURITY_PAGOPAPROVIDER_TOKENURI"
    value = var.pdnd_auth_token_uri
  }

  set {
    name  = "env.SECURITY_PAGOPAPROVIDER_PATHPRIVATEKEY"
    value = "/certs/key.rsa.priv"
  }

  set {
    name  = "env.SECURITY_PAGOPAPROVIDER_PATHPUBLICKEY"
    value = "/certs/key.rsa.pub"
  }

  set {
    name  = "env.SECURITY_PAGOPAPROVIDER_KMSKEYARN"
    value = aws_kms_key.interop_client_key.arn
  }

  set {
    name  = "env.SECURITY_PAGOPAPROVIDER_KID"
    value = var.pdnd_auth_kid
  }

  set {
    name  = "interopApi.privateKey"
    value = var.interop_api_privatekey
  }

  set {
    name  = "interopApi.publicKey"
    value = var.interop_api_publickey
  }

  // TODO da rimuovere
  set {
    name  = "env.SERVER_PORT"
    value = 8080
  }

  // TODO da rimuovere
  set {
    name  = "env.DATABASE_HOST"
    value = module.aurora_postgresql_v2.cluster_endpoint
  }

  // TODO da rimuovere
  set {
    name  = "env.dummy"
    value = "dummy6"
  }
}


resource "kubernetes_job" "demo" {
  metadata {
    name      = "demo"
    namespace = var.namespace
  }
  spec {
    template {
      metadata {}
      spec {
        container {
          name    = "pi"
          image   = "alpine"
          command = ["sh", "-c", "sleep 10"]
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 4
  }

  depends_on = [helm_release.signalhub]
}