output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.eks.certificate_authority[0].data
}

output "eks_cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.eks.arn
}

output "eks_cluster_version" {
  description = "The version of the EKS cluster"
  value       = aws_eks_cluster.eks.version
}

output "eks_cluster_oidc_issuer" {
  description = "The OIDC issuer URL for the EKS cluster"
  value       = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}





# Outputs
output "istio_load_balancer_hostname" {
  description = "Your AWS Load Balancer hostname"
  value       = local.istio_hostname
}

output "osdu_urls" {
  description = "OSDU service endpoints"
  value = {
    main_osdu    = "http://osdu.a894199a15e2a4daa818341e617617b2-586949492.us-east-1.elb.amazonaws.com"
    keycloak     = "http://keycloak.a894199a15e2a4daa818341e617617b2-586949492.us-east-1.elb.amazonaws.com/admin"
    airflow      = "http://airflow.a894199a15e2a4daa818341e617617b2-586949492.us-east-1.elb.amazonaws.com"
    minio        = "http://minio.a894199a15e2a4daa818341e617617b2-586949492.us-east-1.elb.amazonaws.com"
  }
}

output "installation_info" {
  description = "Installation completion info"
  value = <<-EOT
    =====================================================
    OSDU Baremetal Installation Completed (HTTP Mode)
    =====================================================
    
    Using custom-values.yaml file for configuration.
    
    Your OSDU is accessible at:
    - Main OSDU: http://osdu.a894199a15e2a4daa818341e617617b2-586949492.us-east-1.elb.amazonaws.com
    - Keycloak Admin: http://keycloak.a894199a15e2a4daa818341e617617b2-586949492.us-east-1.elb.amazonaws.com/admin
    - Airflow: http://airflow.a894199a15e2a4daa818341e617617b2-586949492.us-east-1.elb.amazonaws.com
    - MinIO: http://minio.a894199a15e2a4daa818341e617617b2-586949492.us-east-1.elb.amazonaws.com
    
    Wait 15-20 minutes for all services to start.
    Check status: kubectl get pods
  EOT
}




# Add after the helm_release
output "osdu_release_status" {
  description = "OSDU Helm release status"
  value = {
    name      = helm_release.osdu-baremetal.name
    namespace = helm_release.osdu-baremetal.namespace
    version   = helm_release.osdu-baremetal.version
    status    = helm_release.osdu-baremetal.status
  }
}