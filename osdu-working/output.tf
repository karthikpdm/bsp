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