data "aws_lb" "load_balancer" {
  tags = {
    "elbv2.k8s.aws/cluster" = "${local.project}-eks"
  }
}

data "aws_lb_target_group" "target_group_push" {
  tags = {
    "elbv2.k8s.aws/cluster"    = "${local.project}-eks",
    "ingress.k8s.aws/resource" = "signalhub/interop-be-signalhub-pull-service-ingress-interop-be-signalhub-push-service-service:8080"
  }
}

data "aws_lb_target_group" "target_group_pull" {
  tags = {
    "elbv2.k8s.aws/cluster"    = "${local.project}-eks",
    "ingress.k8s.aws/resource" = "signalhub/interop-be-signalhub-pull-service-ingress-interop-be-signalhub-pull-service-service:8080"
  }
}

resource "aws_cloudwatch_metric_alarm" "pull_target_response_time" {
  alarm_name          = "${local.project}-Pull-Response-Time"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = lookup(var.time_response_thresholds, "period")
  statistic           = lookup(var.time_response_thresholds, "statistic")
  threshold           = lookup(var.time_response_thresholds, "threshold")
  actions_enabled     = "false"
  alarm_description   = "Trigger an alert when response time in Pull EService goes high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = data.aws_lb_target_group.target_group_pull.arn
    LoadBalancer = data.aws_lb.load_balancer.arn
  }
}

resource "aws_cloudwatch_metric_alarm" "push_target_response_time" {
  alarm_name          = "${local.project}-Push-Response-Time"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = lookup(var.time_response_thresholds, "period")
  statistic           = lookup(var.time_response_thresholds, "statistic")
  threshold           = lookup(var.time_response_thresholds, "threshold")
  actions_enabled     = "false"
  alarm_description   = "Trigger an alert when response time in Push EService goes high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = data.aws_lb_target_group.target_group_push.arn
    LoadBalancer = data.aws_lb.load_balancer.arn
  }
}


resource "aws_cloudwatch_metric_alarm" "pull_target_http_5xx" {
  alarm_name          = "${local.project}-Pull-Http-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = lookup(var.fiveXXs_thresholds, "period")
  statistic           = lookup(var.fiveXXs_thresholds, "statistic")
  threshold           = lookup(var.fiveXXs_thresholds, "threshold")
  actions_enabled     = "false"
  alarm_description   = "Trigger an alert when error 5xx occurs in Pull EService"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = data.aws_lb_target_group.target_group_pull.arn
    LoadBalancer = data.aws_lb.load_balancer.arn
  }
}

resource "aws_cloudwatch_metric_alarm" "push_target_http_5xx" {
  alarm_name          = "${local.project}-Push-Http-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = lookup(var.fiveXXs_thresholds, "period")
  statistic           = lookup(var.fiveXXs_thresholds, "statistic")
  threshold           = lookup(var.time_response_thresholds, "threshold")
  actions_enabled     = "false"
  alarm_description   = "Trigger an alert when error 5xx occurs in Pull EService"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = data.aws_lb_target_group.target_group_push.arn
    LoadBalancer = data.aws_lb.load_balancer.arn
  }
}

