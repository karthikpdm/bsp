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




#########################################################################
# OUTPUTS
#########################################################################
# output "keycloak_access_info" {
#   description = "How to access Keycloak"
#   value = {
#     admin_username = "admin"
#     admin_password = "admin123"
#     public_url     = "http://${data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.hostname}"
#     admin_url      = "http://${data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.hostname}/auth/admin"
#   }
# }

# data "kubernetes_service" "istio_ingress" {
#   metadata {
#     name      = "istio-ingress"
#     namespace = "istio-ingress"
#   }
  
#   depends_on = [helm_release.istio-ingress]
# }



# #########################################################################
# # OUTPUTS
# #########################################################################
# data "kubernetes_service" "istio_gateway" {
#   metadata {
#     name      = "istio-ingress"
#     namespace = "istio-ingress"
#   }
#   depends_on = [helm_release.istio-ingress]
# }

# output "keycloak_url" {
#   description = "Keycloak URL for POC access"
#   value       = "http://${data.kubernetes_service.istio_gateway.status.0.load_balancer.0.ingress.0.hostname}"
# }

# output "keycloak_admin_url" {
#   description = "Keycloak Admin Console URL"
#   value       = "http://${data.kubernetes_service.istio_gateway.status.0.load_balancer.0.ingress.0.hostname}/admin"
# }

# output "keycloak_admin_credentials" {
#   description = "Keycloak Admin Credentials"
#   value = {
#     username = "admin"
#     password = "admin123"
#   }
#   sensitive = false  # For POC only
# }

# output "deployment_method" {
#   description = "Deployment Method Used"
#   value = {
#     method   = "Direct Kubernetes Deployment"
#     reason   = "Helm charts having template/repository issues"
#     image    = "jboss/keycloak:16.1.1"
#     database = "H2 (built-in)"
#     features = "Full Keycloak functionality with Istio service mesh"
#   }
# }