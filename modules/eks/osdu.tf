# #########################################################################
# # OSDU DEPLOYMENT ON EKS WITH ISTIO
# #########################################################################

# #########################################################################
# # STEP 1: Create OSDU Namespace with Istio Injection
# #########################################################################
# resource "kubernetes_namespace" "osdu" {
#   metadata {
#     name = "osdu"  # OSDU typically uses default namespace
#     labels = {
#       name                = "osdu"
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
# # STEP 2: Create Custom Values ConfigMap
# #########################################################################
# resource "kubernetes_config_map" "osdu_custom_values" {
#   metadata {
#     name      = "osdu-custom-values"
#     namespace = "default"
#   }

#   data = {
#     "custom-values.yaml" = local.osdu_custom_values
#   }

#   depends_on = [kubernetes_namespace.osdu]
# }

# #########################################################################
# # STEP 3: OSDU Helm Chart Deployment
# #########################################################################
# resource "helm_release" "osdu" {
#   name             = "osdu-test"
#   namespace        = "osdu"
#   create_namespace = false
  
#   # OSDU Official Helm Chart Repository
#   repository = "oci://community.opengroup.org:5555/osdu/platform/deployment-and-operations/infra-gcp-provisioning/gc-helm"
#   chart      = "osdu-gc-baremetal"
#   version    = "0.27.2"
  
#   # Timeout for OSDU deployment (30-40 minutes as mentioned in docs)
#   timeout = 2400  # 40 minutes
#   wait    = true
  
#   # Custom values configuration
#   values = [local.osdu_custom_values]
  
#   # Force update and recreate pods if needed
#   force_update     = true
#   cleanup_on_fail  = true
#   replace          = true
  
#   depends_on = [
#     kubernetes_namespace.osdu,
#     helm_release.istiod,
#     helm_release.istio-ingress,
#     kubernetes_config_map.osdu_custom_values
#   ]
# }

# #########################################################################
# # STEP 4: Create Istio Gateway for OSDU Services
# #########################################################################
# resource "kubernetes_manifest" "osdu_gateway" {
#   manifest = {
#     apiVersion = "networking.istio.io/v1beta1"
#     kind       = "Gateway"
#     metadata = {
#       name      = "osdu-gateway"
#       namespace = "osdu"
#     }
#     spec = {
#       selector = {
#         istio = "ingress"  # Updated selector to match your istio-ingress
#       }
#       servers = [
#         {
#           port = {
#             number   = 80
#             name     = "http"
#             protocol = "HTTP"
#           }
#           hosts = [
#             # var.osdu_domain_name,  # e.g., "osdu.yourdomain.com"
#             "*"                    # Accept any host for development
#           ]
#         },
#         {
#           port = {
#             number   = 443
#             name     = "https"
#             protocol = "HTTPS"
#           }
#           tls = {
#             mode = "SIMPLE"
#             credentialName = "osdu-tls-secret"
#           }
#           hosts = [
#             # var.osdu_domain_name
#             "*"
#           ]
#         }
#       ]
#     }
#   }

#   depends_on = [
#     helm_release.osdu,
#     helm_release.istio-ingress
#   ]
# }

# #########################################################################
# # STEP 5: OSDU VirtualService for Traffic Routing
# #########################################################################
# resource "kubernetes_manifest" "osdu_virtualservice" {
#   manifest = {
#     apiVersion = "networking.istio.io/v1beta1"
#     kind       = "VirtualService"
#     metadata = {
#       name      = "osdu-vs"
#       namespace = "osdu"
#     }
#     spec = {
#       hosts = [
#         # var.osdu_domain_name,
#         "*"  # Accept any host for development
#       ]
#       gateways = [
#         "osdu-gateway"
#       ]
#       http = [
#         # OSDU API Routes
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
#                 host = "partition.default.svc.cluster.local"
#                 port = {
#                   number = 80
#                 }
#               }
#             }
#           ]
#         },
#         # OSDU Web Portal
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
#                 host = "osdu-web.default.svc.cluster.local"
#                 port = {
#                   number = 80
#                 }
#               }
#             }
#           ]
#         }
#       ]
#     }
#   }

#   depends_on = [kubernetes_manifest.osdu_gateway]
# }

# # #########################################################################
# # # STEP 6: MinIO Gateway for Object Storage (OSDU Dependency)
# # #########################################################################
# # resource "kubernetes_manifest" "minio_gateway" {
# #   count = var.enable_minio_gateway ? 1 : 0
  
# #   manifest = {
# #     apiVersion = "networking.istio.io/v1beta1"
# #     kind       = "Gateway"
# #     metadata = {
# #       name      = "minio-gateway"
# #       namespace = "default"
# #     }
# #     spec = {
# #       selector = {
# #         istio = "ingress"
# #       }
# #       servers = [
# #         {
# #           port = {
# #             number   = 80
# #             name     = "http"
# #             protocol = "HTTP"
# #           }
# #           hosts = [
# #             var.minio_domain_name
# #           ]
# #         }
# #       ]
# #     }
# #   }

# #   depends_on = [helm_release.osdu]
# # }