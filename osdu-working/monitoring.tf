# ----------------------------------------
# Data Sources (reference existing resources)
# ----------------------------------------
data "aws_caller_identity" "current" {}

# Reference your existing EKS cluster
data "aws_eks_cluster" "osdu_cluster" {
  name = aws_eks_cluster.osdu-ir-eks-cluster.name
  depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
}

data "aws_eks_cluster_auth" "osdu_cluster" {
  name = aws_eks_cluster.osdu-ir-eks-cluster.name
  depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
}

# Get OIDC provider from existing cluster
data "tls_certificate" "cluster_oidc_cert" {
  url = aws_eks_cluster.osdu-ir-eks-cluster.identity[0].oidc[0].issuer
}

# ----------------------------------------
# OIDC Provider (create if not exists)
# ----------------------------------------

# Create OIDC provider 
resource "aws_iam_openid_connect_provider" "cluster_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster_oidc_cert.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.osdu-ir-eks-cluster.identity[0].oidc[0].issuer

  tags = merge(
    {
      Name = "${var.cluster_name}-oidc-provider"
    },
    var.monitoring_tags
  )

  # Prevent recreation if provider already exists
  lifecycle {
    ignore_changes = [thumbprint_list]
  }
}

# ----------------------------------------
# 1. AMAZON MANAGED PROMETHEUS (AMP)
# ----------------------------------------

# CloudWatch Log Group for Prometheus
resource "aws_cloudwatch_log_group" "prometheus_logs" {
  name              = "/aws/prometheus/${var.cluster_name}"
  retention_in_days = 30

  tags = merge(
    {
      Name = "${var.cluster_name}-prometheus-logs"
    },
    var.monitoring_tags
  )
}

# Create AMP Workspace
resource "aws_prometheus_workspace" "osdu_prometheus" {
  alias = "${var.cluster_name}-prometheus"
  
  logging_configuration {
    log_group_arn = "${aws_cloudwatch_log_group.prometheus_logs.arn}:*"
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-prometheus"
    },
    var.monitoring_tags
  )
}

# ----------------------------------------
# 2. IAM ROLES AND POLICIES FOR MONITORING
# ----------------------------------------

# Get OIDC provider details
locals {
  oidc_provider_arn = aws_iam_openid_connect_provider.cluster_oidc.arn
  oidc_provider_url = replace(aws_eks_cluster.osdu-ir-eks-cluster.identity[0].oidc[0].issuer, "https://", "")
}

# IAM Role for ADOT Collector
resource "aws_iam_role" "adot_collector_role" {
  name = "${var.cluster_name}-adot-collector-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:adot:adot-collector"
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
        Principal = {
          Federated = local.oidc_provider_arn
        }
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.cluster_name}-adot-collector-role"
    },
    var.monitoring_tags
  )
}

# IAM Policy for AMP Remote Write
resource "aws_iam_policy" "amp_remote_write_policy" {
  name        = "${var.cluster_name}-amp-remote-write"
  description = "Policy for ADOT to write to Amazon Managed Prometheus"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ]
        Resource = aws_prometheus_workspace.osdu_prometheus.arn
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.cluster_name}-amp-remote-write"
    },
    var.monitoring_tags
  )
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "adot_amp_policy" {
  role       = aws_iam_role.adot_collector_role.name
  policy_arn = aws_iam_policy.amp_remote_write_policy.arn
}

# IAM Role for CloudWatch Agent
resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "${var.cluster_name}-cloudwatch-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
        Principal = {
          Federated = local.oidc_provider_arn
        }
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.cluster_name}-cloudwatch-agent-role"
    },
    var.monitoring_tags
  )
}

# CloudWatch Agent Policy
resource "aws_iam_policy" "cloudwatch_agent_policy" {
  name        = "${var.cluster_name}-cloudwatch-agent"
  description = "Policy for CloudWatch Agent"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.cluster_name}-cloudwatch-agent"
    },
    var.monitoring_tags
  )
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = aws_iam_policy.cloudwatch_agent_policy.arn
}

# ----------------------------------------
# 3. AMAZON MANAGED GRAFANA (AMG)
# ----------------------------------------

# IAM Role for Grafana
resource "aws_iam_role" "grafana_role" {
  name = "${var.cluster_name}-grafana-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "grafana.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.cluster_name}-grafana-role"
    },
    var.monitoring_tags
  )
}

# Grafana CloudWatch Policy
resource "aws_iam_policy" "grafana_cloudwatch_policy" {
  name        = "${var.cluster_name}-grafana-cloudwatch"
  description = "Policy for Grafana to access CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:DescribeQueries",
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.cluster_name}-grafana-cloudwatch"
    },
    var.monitoring_tags
  )
}

# Grafana Prometheus Policy
resource "aws_iam_policy" "grafana_prometheus_policy" {
  name        = "${var.cluster_name}-grafana-prometheus"
  description = "Policy for Grafana to access Prometheus"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:ListWorkspaces",
          "aps:DescribeWorkspace",
          "aps:QueryMetrics",
          "aps:GetLabels",
          "aps:GetSeries",
          "aps:GetMetricMetadata"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.cluster_name}-grafana-prometheus"
    },
    var.monitoring_tags
  )
}

# Attach policies to Grafana role
resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana_role.name
  policy_arn = aws_iam_policy.grafana_cloudwatch_policy.arn
}

resource "aws_iam_role_policy_attachment" "grafana_prometheus" {
  role       = aws_iam_role.grafana_role.name
  policy_arn = aws_iam_policy.grafana_prometheus_policy.arn
}

# Amazon Managed Grafana Workspace
resource "aws_grafana_workspace" "osdu_grafana" {
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                = aws_iam_role.grafana_role.arn
  
  data_sources = [
    "CLOUDWATCH",
    "PROMETHEUS"
  ]
  
  notification_destinations = ["SNS"]
  
  name        = "${var.cluster_name}-grafana"
  description = "OSDU Platform Monitoring Dashboard"

  tags = merge(
    {
      Name = "${var.cluster_name}-grafana"
    },
    var.monitoring_tags
  )
}

# ----------------------------------------
# 4. KUBERNETES PROVIDER CONFIGURATION
# ----------------------------------------

# # Configure Kubernetes provider using existing cluster
# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.osdu_cluster.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.osdu_cluster.certificate_authority[0].data)
#   token                  = data.aws_eks_cluster_auth.osdu_cluster.token
# }

# ----------------------------------------
# 5. KUBERNETES NAMESPACES
# ----------------------------------------

# CloudWatch namespace
resource "kubernetes_namespace" "amazon_cloudwatch" {
  count = var.enable_cloudwatch_insights ? 1 : 0
  
  metadata {
    name = "amazon-cloudwatch"
    
    labels = {
      name = "amazon-cloudwatch"
    }
  }

  depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
}

# ADOT namespace
resource "kubernetes_namespace" "adot" {
  metadata {
    name = "adot"
    
    labels = {
      name = "adot"
    }
  }

  depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
}

# Monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    
    labels = {
      name = "monitoring"
    }
  }

  depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
}

# ----------------------------------------
# 6. KUBERNETES SERVICE ACCOUNTS
# ----------------------------------------

# Service Account for ADOT Collector
resource "kubernetes_service_account" "adot_collector" {
  metadata {
    name      = "adot-collector"
    namespace = kubernetes_namespace.adot.metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.adot_collector_role.arn
    }
  }

  depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
}

# Service Account for CloudWatch Agent
resource "kubernetes_service_account" "cloudwatch_agent" {
  count = var.enable_cloudwatch_insights ? 1 : 0
  
  metadata {
    name      = "cloudwatch-agent"
    namespace = kubernetes_namespace.amazon_cloudwatch[0].metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cloudwatch_agent_role.arn
    }
  }

  depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
}

# ----------------------------------------
# 7. ADOT COLLECTOR CONFIGURATION
# ----------------------------------------

# ADOT Collector ConfigMap
resource "kubernetes_config_map" "adot_collector_config" {
  metadata {
    name      = "adot-collector-config"
    namespace = kubernetes_namespace.adot.metadata[0].name
  }

  data = {
    "adot-config.yaml" = yamlencode({
      receivers = {
        prometheus = {
          config = {
            global = {
              scrape_interval = "15s"
              evaluation_interval = "15s"
            }
            scrape_configs = [
              {
                job_name = "kubernetes-apiservers"
                kubernetes_sd_configs = [
                  {
                    role = "endpoints"
                  }
                ]
                scheme = "https"
                tls_config = {
                  ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
                }
                bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
                relabel_configs = [
                  {
                    source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_service_name", "__meta_kubernetes_endpoint_port_name"]
                    action = "keep"
                    regex = "default;kubernetes;https"
                  }
                ]
              },
              {
                job_name = "kubernetes-nodes"
                kubernetes_sd_configs = [
                  {
                    role = "node"
                  }
                ]
                scheme = "https"
                tls_config = {
                  ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
                }
                bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
                relabel_configs = [
                  {
                    action = "labelmap"
                    regex = "__meta_kubernetes_node_label_(.+)"
                  }
                ]
              },
              {
                job_name = "kubernetes-cadvisor"
                kubernetes_sd_configs = [
                  {
                    role = "node"
                  }
                ]
                scheme = "https"
                metrics_path = "/metrics/cadvisor"
                tls_config = {
                  ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
                }
                bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
                relabel_configs = [
                  {
                    action = "labelmap"
                    regex = "__meta_kubernetes_node_label_(.+)"
                  }
                ]
              },
              {
                job_name = "kubernetes-service-endpoints"
                kubernetes_sd_configs = [
                  {
                    role = "endpoints"
                  }
                ]
                relabel_configs = [
                  {
                    source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_scrape"]
                    action = "keep"
                    regex = true
                  },
                  {
                    source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_path"]
                    action = "replace"
                    target_label = "__metrics_path__"
                    regex = "(.+)"
                  }
                ]
              },
              {
                job_name = "osdu-pods"
                kubernetes_sd_configs = [
                  {
                    role = "pod"
                    namespaces = {
                      names = ["default"]
                    }
                  }
                ]
                relabel_configs = [
                  {
                    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                    action = "keep"
                    regex = true
                  },
                  {
                    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                    action = "replace"
                    target_label = "__metrics_path__"
                    regex = "(.+)"
                  },
                  {
                    source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
                    action = "replace"
                    regex = "([^:]+)(?::\\d+)?;(\\d+)"
                    replacement = "$1:$2"
                    target_label = "__address__"
                  }
                ]
              }
            ]
          }
        }
      }
      
      processors = {
        batch = {}
        
        resource = {
          attributes = [
            {
              key = "cluster_name"
              value = var.cluster_name
              action = "insert"
            },
            {
              key = "region"
              value = var.region
              action = "insert"
            }
          ]
        }
      }
      
      exporters = {
        prometheusremotewrite = {
          endpoint = "${aws_prometheus_workspace.osdu_prometheus.prometheus_endpoint}api/v1/remote_write"
          auth = {
            authenticator = "sigv4auth"
          }
          resource_to_telemetry_conversion = {
            enabled = true
          }
        }
      }
      
      extensions = {
        health_check = {}
        pprof = {}
        zpages = {}
        
        sigv4auth = {
          region = var.region
          service = "aps"
        }
      }
      
      service = {
        extensions = ["health_check", "pprof", "zpages", "sigv4auth"]
        pipelines = {
          metrics = {
            receivers = ["prometheus"]
            processors = ["batch", "resource"]
            exporters = ["prometheusremotewrite"]
          }
        }
      }
    })
  }

  depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
}

# ----------------------------------------
# 8. ADOT COLLECTOR DEPLOYMENT
# ----------------------------------------

resource "kubernetes_deployment" "adot_collector" {
  metadata {
    name      = "adot-collector"
    namespace = kubernetes_namespace.adot.metadata[0].name
    
    labels = {
      app = "adot-collector"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "adot-collector"
      }
    }

    template {
      metadata {
        labels = {
          app = "adot-collector"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.adot_collector.metadata[0].name

        container {
          name  = "adot-collector"
          image = "public.ecr.aws/aws-observability/aws-otel-collector:v0.40.0"

          command = [
            "/awscollector",
            "--config=/conf/adot-config.yaml"
          ]

          volume_mount {
            name       = "adot-collector-config-vol"
            mount_path = "/conf"
          }

          env {
            name = "AWS_REGION"
            value = var.region
          }

          resources {
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
            requests = {
              memory = "1Gi"
              cpu    = "500m"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 13133
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 13133
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        volume {
          name = "adot-collector-config-vol"
          config_map {
            name = kubernetes_config_map.adot_collector_config.metadata[0].name
          }
        }

        # Schedule on frontend nodes (untainted for flexible scheduling)
        node_selector = {
          "node-role" = "osdu-frontend"
        }

        # Add toleration for any potential taints on frontend nodes
        toleration {
          key      = "node-role"
          operator = "Equal"
          value    = "osdu-frontend"
          effect   = "NoSchedule"
        }
      }
    }
  }

  depends_on = [
    aws_eks_cluster.osdu-ir-eks-cluster,
    aws_eks_node_group.osdu_ir_frontend_node
  ]
}

# ----------------------------------------
# 9. CLOUDWATCH CONTAINER INSIGHTS
# ----------------------------------------

# CloudWatch Agent ConfigMap
resource "kubernetes_config_map" "cloudwatch_config" {
  count = var.enable_cloudwatch_insights ? 1 : 0
  
  metadata {
    name      = "cwagentconfig"
    namespace = kubernetes_namespace.amazon_cloudwatch[0].metadata[0].name
  }

  data = {
    "cwagentconfig.json" = jsonencode({
      logs = {
        metrics_collected = {
          kubernetes = {
            cluster_name = var.cluster_name
            metrics_collection_interval = 60
          }
        }
        force_flush_interval = 5
      }
    })
  }

  depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
}

# CloudWatch Agent DaemonSet
resource "kubernetes_daemonset" "cloudwatch_agent" {
  count = var.enable_cloudwatch_insights ? 1 : 0
  
  metadata {
    name      = "cloudwatch-agent"
    namespace = kubernetes_namespace.amazon_cloudwatch[0].metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        name = "cloudwatch-agent"
      }
    }

    template {
      metadata {
        labels = {
          name = "cloudwatch-agent"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.cloudwatch_agent[0].metadata[0].name

        container {
          name  = "cloudwatch-agent"
          image = "amazon/cloudwatch-agent:1.300026.2b374"

          resources {
            limits = {
              memory = "200Mi"
              cpu    = "200m"
            }
            requests = {
              memory = "200Mi"
              cpu    = "200m"
            }
          }

          env {
            name = "AWS_REGION"
            value = var.region
          }

          env {
            name = "CW_CONFIG_CONTENT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.cloudwatch_config[0].metadata[0].name
                key  = "cwagentconfig.json"
              }
            }
          }

          volume_mount {
            name       = "cwagentconfig"
            mount_path = "/etc/cwagentconfig"
          }

          volume_mount {
            name       = "rootfs"
            mount_path = "/rootfs"
            read_only  = true
          }

          volume_mount {
            name       = "dockersock"
            mount_path = "/var/run/docker.sock"
            read_only  = true
          }

          volume_mount {
            name       = "varlibdocker"
            mount_path = "/var/lib/docker"
            read_only  = true
          }

          volume_mount {
            name       = "sys"
            mount_path = "/sys"
            read_only  = true
          }

          volume_mount {
            name       = "devdisk"
            mount_path = "/dev/disk"
            read_only  = true
          }
        }

        volume {
          name = "cwagentconfig"
          config_map {
            name = kubernetes_config_map.cloudwatch_config[0].metadata[0].name
          }
        }

        volume {
          name = "rootfs"
          host_path {
            path = "/"
          }
        }

        volume {
          name = "dockersock"
          host_path {
            path = "/var/run/docker.sock"
          }
        }

        volume {
          name = "varlibdocker"
          host_path {
            path = "/var/lib/docker"
          }
        }

        volume {
          name = "sys"
          host_path {
            path = "/sys"
          }
        }

        volume {
          name = "devdisk"
          host_path {
            path = "/dev/disk/"
          }
        }

        termination_grace_period_seconds = 60
        host_network                     = true
        
        # Tolerations to run on all nodes
        toleration {
          operator = "Exists"
        }
      }
    }
  }

  depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
}

# ----------------------------------------
# 10. SNS TOPIC FOR ALERTS
# ----------------------------------------

resource "aws_sns_topic" "osdu_alerts" {
  name = "${var.cluster_name}-monitoring-alerts"

  tags = merge(
    {
      Name = "${var.cluster_name}-monitoring-alerts"
    },
    var.monitoring_tags
  )
}

resource "aws_sns_topic_subscription" "osdu_alerts_email" {
  topic_arn = aws_sns_topic.osdu_alerts.arn
  protocol  = "email"
  endpoint  = var.grafana_admin_email
}

# ----------------------------------------
# 11. OSDU-SPECIFIC SERVICE MONITORS (using kubectl apply)
# ----------------------------------------

# Apply service monitors using null_resource since they require CRDs
resource "null_resource" "apply_service_monitors" {
  provisioner "local-exec" {
    command = <<-EOT
      # Update kubeconfig
      aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}
      
      # Create service monitor for OSDU services
      kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: osdu-services
  namespace: monitoring
  labels:
    app: osdu-monitoring
spec:
  selector:
    matchLabels:
      monitoring: "enabled"
  endpoints:
  - port: metrics
    path: /actuator/prometheus
    interval: 30s
    relabelings:
    - sourceLabels: [__meta_kubernetes_service_name]
      targetLabel: service
    - sourceLabels: [__meta_kubernetes_namespace]
      targetLabel: namespace
  namespaceSelector:
    matchNames: ["default"]
EOF

      # Create PrometheusRule for alerts
      kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: osdu-alerts
  namespace: monitoring
  labels:
    app: osdu-monitoring
spec:
  groups:
  - name: osdu.rules
    rules:
    - alert: OSPodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{namespace="default"}[15m]) > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ \$labels.pod }} is crash looping"
        description: "Pod {{ \$labels.pod }} in namespace {{ \$labels.namespace }} is restarting frequently."
    - alert: OSHighMemoryUsage
      expr: (container_memory_usage_bytes{namespace="default"} / container_spec_memory_limit_bytes) > 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage detected"
        description: "Container {{ \$labels.container }} in pod {{ \$labels.pod }} is using high memory."
    - alert: OSServiceDown
      expr: up{namespace="default"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "OSDU Service {{ \$labels.job }} is down"
        description: "OSDU Service {{ \$labels.job }} has been down for more than 1 minute."
    - alert: OSAirflowBootstrapFailing
      expr: kube_pod_status_phase{pod=~"airflow-bootstrap.*", phase="Failed"} > 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Airflow bootstrap pod failing"
        description: "Airflow bootstrap pod is in failed state."
    - alert: OSSchemaBootstrapFailing
      expr: kube_pod_status_phase{pod=~"schema-bootstrap.*", phase="Failed"} > 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Schema bootstrap pod failing"
        description: "Schema bootstrap pod is in failed state."
EOF
    EOT
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    aws_eks_cluster.osdu-ir-eks-cluster
  ]

  triggers = {
    cluster_name = var.cluster_name
    region      = var.region
  }
}





















# ----------------------------------------
# 12. OUTPUTS
# ----------------------------------------

output "prometheus_workspace_id" {
  description = "Amazon Managed Prometheus workspace ID"
  value       = aws_prometheus_workspace.osdu_prometheus.id
}

output "prometheus_endpoint" {
  description = "Amazon Managed Prometheus endpoint"
  value       = aws_prometheus_workspace.osdu_prometheus.prometheus_endpoint
}

output "grafana_workspace_id" {
  description = "Amazon Managed Grafana workspace ID"
  value       = aws_grafana_workspace.osdu_grafana.id
}

output "grafana_endpoint" {
  description = "Amazon Managed Grafana endpoint"
  value       = aws_grafana_workspace.osdu_grafana.endpoint
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for monitoring"
  value       = var.enable_cloudwatch_insights ? kubernetes_config_map.cloudwatch_config[0].metadata[0].name : "Not enabled"
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.osdu_alerts.arn
}

output "monitoring_setup_commands" {
  description = "Commands to verify monitoring setup"
  value = <<-EOT
    # Update kubeconfig
    aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}
    
    # Check monitoring components
    kubectl get pods -n adot
    kubectl get pods -n amazon-cloudwatch
    kubectl get pods -n monitoring
    
    # Check service monitors
    kubectl get servicemonitors -n monitoring
    
    # Check alerts
    kubectl get prometheusrules -n monitoring
    
    # Access Grafana at:
    echo "Grafana URL: ${aws_grafana_workspace.osdu_grafana.endpoint}"
  EOT
}
