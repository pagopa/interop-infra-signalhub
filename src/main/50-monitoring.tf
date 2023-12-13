resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }

  depends_on = [module.eks]
}

#resource "helm_release" "metrics_server" {
#  name       = "metrics-server"
#  chart      = "metrics-server"
#  repository = "https://kubernetes-sigs.github.io/metrics-server"
#  version    = var.helm_metrics_server_version
#  namespace  = kubernetes_namespace.monitoring.id
#
#  set {
#    name  = "containerPort"
#    value = 4443
#  }
#
#  set {
#    name  = "args[0]"
#    value = "--kubelet-insecure-tls"
#  }
#}
#
#resource "kubectl_manifest" "metrics_server_sg" {
#  yaml_body = yamlencode({
#    apiVersion = "vpcresources.k8s.aws/v1beta1"
#    kind       = "SecurityGroupPolicy"
#
#    metadata = {
#      name      = "metrics-server"
#      namespace = kubernetes_namespace.monitoring.id
#    }
#
#    spec = {
#      podSelector = {
#        matchLabels = {
#          "app.kubernetes.io/instance" = "metrics-server"
#          "app.kubernetes.io/name"     = "metrics-server"
#        }
#      }
#
#      securityGroups = {
#        groupIds = [
#          module.eks.cluster_primary_security_group_id
#        ]
#      }
#    }
#  })
#}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = var.helm_prometheus_version
  namespace  = kubernetes_namespace.monitoring.id
  values     = ["${file("assets/prometheus_values.yaml")}"]
}

resource "random_password" "grafana" {
  length  = 20
  special = false
}

resource "kubernetes_secret" "grafana_admin_secret" {
  metadata {
    name      = "grafana-admin-secret"
    namespace = kubernetes_namespace.monitoring.id
  }

  data = {
    "admin-user"     = "admin",
    "admin-password" = random_password.grafana.result
  }
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.id
  values     = ["${file("assets/grafana_values.yaml")}"]
}

