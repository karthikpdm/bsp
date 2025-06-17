# # Add this to your Terraform
# resource "kubernetes_namespace" "microservices" {
#   metadata {
#     name = "microservices"
#     labels = {
#       "istio-injection" = "enabled"  # This enables sidecar injection
#       "app"             = "microservices"
#     }
#   }
  
#   depends_on = [helm_release.istiod]
# }



# ######################################################################################################################################


# #########################################################################
# # SINGLE GATEWAY for ALL Services (One Entry Point)
# #########################################################################
# resource "kubernetes_manifest" "main_gateway" {
#   manifest = {
#     apiVersion = "networking.istio.io/v1beta1"
#     kind       = "Gateway"
#     metadata = {
#       name      = "main-gateway"
#       namespace = "istio-ingress"
#     }
#     spec = {
#       selector = {
#         app = "istio-ingress"
#       }
#       servers = [
#         {
#           port = {
#             number   = 80
#             name     = "http"
#             protocol = "HTTP"
#           }
#           hosts = ["*"]  # For POC, accept any host/IP
#         }
#       ]
#     }
#   }
  
#   depends_on = [helm_release.istio-ingress]
# }



# #########################################################################
# # VirtualService 1: REST API Service (Main Application)
# #########################################################################
# resource "kubernetes_manifest" "rest_api_virtualservice" {
#   manifest = {
#     apiVersion = "networking.istio.io/v1beta1"
#     kind       = "VirtualService"
#     metadata = {
#       name      = "rest-api-routing"
#       namespace = kubernetes_namespace.microservices.metadata[0].name
#     }
#     spec = {
#       hosts = ["*"]
#       gateways = ["istio-ingress/main-gateway"]
#       http = [
#         {
#           match = [
#             {
#               uri = {
#                 prefix = "/api/"
#               }
#             }
#           ]
#           route = [
#             {
#               destination = {
#                 host = "rest-api.microservices.svc.cluster.local"
#                 port = {
#                   number = 8080
#                 }
#               }
#             }
#           ]
#           headers = {
#             request = {
#               set = {
#                 "x-service-name" = "rest-api"
#               }
#             }
#           }
#         }
#       ]
#     }
#   }
  
#   depends_on = [kubernetes_manifest.main_gateway]
# }


# ######################################################################################################################################

# ######################################################################################################################################

# resource "helm_release" "postgresql" {
#   name             = "postgresql"
#   namespace        = kubernetes_namespace.microservices.metadata[0].name
#   repository       = "https://charts.bitnami.com/bitnami"
#   chart            = "postgresql"
#   version          = "13.2.24"

#   set {
#     name  = "auth.postgresPassword"
#     value = var.postgres_password
#   }
  
#   set {
#     name  = "auth.database"
#     value = "microservices_db"
#   }
  
#   set {
#     name  = "primary.persistence.enabled"
#     value = "true"
#   }
  
#   set {
#     name  = "primary.persistence.size"
#     value = "10Gi"
#   }
  
#   set {
#     name  = "primary.persistence.storageClass"
#     value = "gp2"
#   }

#   depends_on = [kubernetes_namespace.microservices]
# }

# ######################################################################################################################################






# ######################################################################################################################################




# resource "helm_release" "elasticsearch" {
#   name             = "elasticsearch"
#   namespace        = kubernetes_namespace.microservices.metadata[0].name
#   repository       = "https://helm.elastic.co"
#   chart            = "elasticsearch"
#   version          = "8.5.1"

#   set {
#     name  = "replicas"
#     value = "1"  # Single node for POC
#   }
  
#   set {
#     name  = "minimumMasterNodes"
#     value = "1"
#   }
  
#   set {
#     name  = "persistence.enabled"
#     value = "true"
#   }
  
#   set {
#     name  = "persistence.size"
#     value = "30Gi"
#   }
  
#   set {
#     name  = "volumeClaimTemplate.storageClassName"
#     value = "gp3"
#   }
  
#   set {
#     name  = "resources.requests.memory"
#     value = "1Gi"
#   }
  
#   set {
#     name  = "resources.limits.memory"
#     value = "2Gi"
#   }

#   depends_on = [kubernetes_namespace.microservices]
# }







# resource "helm_release" "minio" {
#   name             = "minio"
#   namespace        = kubernetes_namespace.microservices.metadata[0].name
#   repository       = "https://charts.bitnami.com/bitnami"
#   chart            = "minio"
#   version          = "12.8.18"

#   set {
#     name  = "auth.rootUser"
#     value = "admin"
#   }
  
#   set {
#     name  = "auth.rootPassword"
#     value = var.minio_password
#   }
  
#   set {
#     name  = "persistence.enabled"
#     value = "true"
#   }
  
#   set {
#     name  = "persistence.size"
#     value = "50Gi"
#   }
  
#   set {
#     name  = "persistence.storageClass"
#     value = "gp3"
#   }

#   depends_on = [kubernetes_namespace.microservices]
# }