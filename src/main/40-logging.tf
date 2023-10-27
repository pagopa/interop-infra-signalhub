resource "kubernetes_namespace" "log" {
  metadata {
    name = "aws-observability"

    labels = {
      aws-observability = "enabled"
    }
  }
}

resource "kubernetes_config_map" "log" {
  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace.log.id
  }

  data = {
    flb_log_cw     = "false"
    "output.conf"  = <<-EOT
      [OUTPUT]
        Name cloudwatch_logs
        Match kube.*
        region ${var.aws_region}
        log_group_name /aws/${local.project}/cluster
        log_retention_days 7
        auto_create_group true
      [OUTPUT]
        Name cloudwatch_logs
        Match *
        region ${var.aws_region}
        log_group_name /aws/${local.project}/ms
        log_retention_days 7
        auto_create_group true
    EOT
    "filters.conf" = <<-EOF
      [FILTER]
        Name     parser
        Match    *
        Key_Name log
        Parser   slf4j
        Preserve_Key true
        Reserve_Data true
      [FILTER]
        Name kubernetes
        Match kube.*
        Merge_Log On
        Keep_Log Off
        Buffer_Size 0
        Kube_Meta_Cache_TTL 300s
    EOF
    "parsers.conf" = <<-EOF
      [PARSER]
        Name        slf4j
        Format      regex
        Regex       ^(?<TIME>\d+-\d+-\d+ \d+:\d+:\d+\.\d+)\s+(?<LEVEL>\S+) \d+ --- \[\s*(?<THREAD>[^\]]+)\] (?<CONTEXT>\S+)\s+: (?<MESSAGE>.*)$
        Time_Key    TIME
        Time_Format %Y/%m/%d %H:%M:%S.%L
    EOF
  }
}

resource "aws_iam_policy" "log" {
  name        = "eks-fargate-logging-access"
  path        = "/"
  description = "Enable Fargate FluentBit to export logs into CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

locals {
  fargate_log_role_names = toset([for each in module.eks.fargate_profiles : each.iam_role_name if strcontains(each.iam_role_name, local.project)])
}

resource "aws_iam_role_policy_attachment" "log" {
  for_each = local.fargate_log_role_names

  role       = each.value
  policy_arn = aws_iam_policy.log.arn
}
