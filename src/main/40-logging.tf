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
        log_group_name /aws/pod/${local.project}/
        log_retention_days 7
        log_stream_prefix fallback-stream
        log_stream_template $kubernetes['pod_name']
        auto_create_group true
    EOT
    "filters.conf" = <<-EOF
      [FILTER]
        Name     parser
        Match    kube.*
        Key_Name log
        Parser   slf4j
        Preserve_Key false
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
        Regex       ^(?<t>[^ ]+) (?<stream>stdout|stderr) (?<logtag>P|F) (?<time>\d+-\d+-\d+\s\d+:\d+:\d+\.\d+)\s+(?<level>\S+) \d+ --- \[\s*(?<thread>[^\]]+)\] (?<context>\S+)\s+: (?<message>.*)$
        Time_Key    t
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
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
          "logs:PutLogEvents",
          "logs:PutRetentionPolicy"
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
