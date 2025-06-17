# #########################################################################
# # KEYCLOAK DEPLOYMENT - DIRECT KUBERNETES (NO HELM ISSUES)
# #########################################################################

# #########################################################################
# # STEP 1: Create Keycloak Namespace with Istio Injection
# #########################################################################
# resource "kubernetes_namespace" "keycloak" {
#   metadata {
#     name = "keycloak"
#     labels = {
#       name                = "keycloak"
#       "istio-injection"   = "enabled"  # Enable Istio sidecar injection
#     }
#   }
  
#   depends_on = [
#     aws_eks_cluster.eks,
#     aws_eks_node_group.node-grp,
#     helm_release.istiod
#   ]
# }

# #########################################################################
# # STEP 2: Keycloak Deployment (Direct Kubernetes - No Helm Charts)
# #########################################################################
# resource "kubernetes_deployment" "keycloak" {
#   metadata {
#     name      = "keycloak"
#     namespace = kubernetes_namespace.keycloak.metadata[0].name
#     labels = {
#       app = "keycloak"
#     }
#   }

#   spec {
#     replicas = 1
#     selector {
#       match_labels = {
#         app = "keycloak"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "keycloak"
#         }
#       }

#       spec {
#         container {
#           image = "keycloak/keycloak:22.0"
#           name  = "keycloak"

#           args = ["start-dev"]

#           env {
#             name  = "KEYCLOAK_ADMIN"
#             value = "admin"
#           }
#           env {
#             name  = "KEYCLOAK_ADMIN_PASSWORD"
#             value = "admin123"
#           }
#           env {
#             name  = "KC_PROXY"
#             value = "edge"
#           }
#           env {
#             name  = "KC_HOSTNAME_STRICT"
#             value = "false"
#           }
#           env {
#             name  = "KC_HTTP_ENABLED"
#             value = "true"
#           }
#           env {
#             name  = "KC_HOSTNAME_STRICT_HTTPS"
#             value = "false"
#           }

#           env {
#             name  = "KC_SPI_LOGIN_PROTOCOL_OPENID_CONNECT_LEGACY_LOGOUT_REDIRECT_URI"
#             value = "true"
#           }

#           port {
#             container_port = 8080
#             name           = "http"
#           }

#           resources {
#             requests = {
#               memory = "512Mi"
#               cpu    = "500m"
#             }
#             limits = {
#               memory = "512Mi"
#               cpu    = "1000m"
#             }
#           }

#         }
#       }
#     }
#   }

#   depends_on = [kubernetes_namespace.keycloak]
# }
# #########################################################################
# # STEP 3: Keycloak Service
# #########################################################################
# resource "kubernetes_service" "keycloak" {
#   metadata {
#     name      = "keycloak"
#     namespace = kubernetes_namespace.keycloak.metadata[0].name
#     labels = {
#       app = "keycloak"
#     }
#   }

#   spec {
#     selector = {
#       app = "keycloak"
#     }

#     port {
#       port        = 8080
#       target_port = 8080
#       protocol    = "TCP"
#       name        = "http"
#     }

#     type = "ClusterIP"
#   }

#   depends_on = [kubernetes_deployment.keycloak]
# }

# #########################################################################
# # STEP 4: Istio Gateway for Keycloak
# #########################################################################
# resource "kubernetes_manifest" "keycloak_gateway" {
#   manifest = {
#     apiVersion = "networking.istio.io/v1beta1"
#     kind       = "Gateway"
#     metadata = {
#       name      = "keycloak-gateway"
#       namespace = kubernetes_namespace.keycloak.metadata[0].name
#     }
#     spec = {
#       selector = {
#         istio = "ingress"
#       }
#       servers = [
#         {
#           port = {
#             number   = 80
#             name     = "http"
#             protocol = "HTTP"
#           }
#           hosts = [
#             "*"  # Accept any host for POC
#           ]
#         }
#       ]
#     }
#   }

#   depends_on = [
#     kubernetes_service.keycloak,
#     helm_release.istio-ingress
#   ]
# }

# #########################################################################
# # STEP 5: Istio VirtualService for Keycloak
# #########################################################################
# resource "kubernetes_manifest" "keycloak_virtualservice" {
#   manifest = {
#     apiVersion = "networking.istio.io/v1beta1"
#     kind       = "VirtualService"
#     metadata = {
#       name      = "keycloak-vs"
#       namespace = kubernetes_namespace.keycloak.metadata[0].name
#     }
#     spec = {
#       hosts = [
#         "*"  # Accept any host for POC
#       ]
#       gateways = [
#         "keycloak-gateway"
#       ]
#       http = [
#         {
#           match = [
#             {
#               uri = {
#                 prefix = "/"
#               }
#             }
#           ]
#           route = [
#             {
#               destination = {
#                 host = "keycloak.keycloak.svc.cluster.local"
#                 port = {
#                   number = 8080
#                 }
#               }
#             }
#           ]
#         }
#       ]
#     }
#   }

#   depends_on = [kubernetes_manifest.keycloak_gateway]
# }