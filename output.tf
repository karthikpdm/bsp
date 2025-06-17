
# #########################################################################
# # KEYCLOAK OUTPUTS
# #########################################################################
# data "kubernetes_service" "istio_gateway" {
#   metadata {
#     name      = "istio-ingress"
#     namespace = "istio-ingress"
#   }
# #   depends_on = [module.eks.helm_release.istio-ingress]
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
#   sensitive = false
# }