# # helm repo add istio https://istio-release.storage.googleapis.com/charts
# # helm repo update
# # helm install demo-eks-istio-base -n istio-system --create-namespace istio/base --set global.istioNamespace=istio-system
# # helm install demo-eks-istiod -n istio-system --create-namespace istio/istiod --set telemetry.enabled=true --set global.istioNamespace=istio-system
# # helm install demo-eks-istio-gateway -n istio-system --create-namespace istio/gateway

# # Create namespace
# resource "kubernetes_namespace" "istio-namespace" {
#   metadata {
#     name = "istio-system"
#   }
# }

# # Create namespace
# resource "kubernetes_namespace" "istio-gateway-namespace" {
#   metadata {
#     name = "istio-gateway"
#   }
# }

# resource "null_resource" "update_kubeconfig" {
#   provisioner "local-exec" {
#     command = "echo 'Updating kubeconfig...' && aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}"
#   }

#   triggers = {
#     cluster_name = var.cluster_name
#     region       = var.region
#   }
#   depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
# }

# resource "null_resource" "label_default_namespace" {
#   provisioner "local-exec" {
#     command = "echo 'Labeling default namespace for Istio sidecar injection...' && kubectl label namespace default istio-injection=enabled --overwrite"
#   }

#   depends_on = [
#     null_resource.update_kubeconfig,
#     helm_release.osdu-ir-istio-istiod
#   ]
# }

# # Creating the Istio Base
# resource "helm_release" "osdu-ir-istio-base" {
#   name = "osdu-ir-istio-base"
#   /* The Zscaler was blocking this so the tgz files were 
#   /  downloaded to local folder
#   / Use your cognizance for this */
#   # repository = "https://istio-release.storage.googleapis.com/charts"
#   # chart      = "base"
#   chart     = "${path.module}/charts/istio-base-1.21.0.tgz"
#   namespace = kubernetes_namespace.istio-namespace.metadata[0].name
#   version   = "1.21.0"
#   depends_on = [
#     kubernetes_namespace.istio-namespace,
#     aws_eks_addon.osdu-ir-csi-addon
#   ]
# }

# # Deploying the Istiod 
# # resource "helm_release" "osdu-ir-istio-istiod" {
# #   name = "osdu-ir-istio-istiod"
# #   /* The Zscaler was blocking this so the tgz files were 
# #   /  downloaded to local folder
# #   / Use your cognizance for this */
# #   # repository = "https://istio-release.storage.googleapis.com/charts"
# #   # chart      = "istiod"
# #   chart     = "${path.module}/charts/istiod-1.21.0.tgz"
# #   namespace = kubernetes_namespace.istio-namespace.metadata[0].name
# #   version   = "1.21.0"

# #   values = [
# #     yamlencode({
# #       global = {
# #         proxy = {
# #           autoInject = "enabled"
# #         }
# #       }
# #       pilot = {
# #         nodeSelector = {
# #           "node-role" = "osdu-istio-keycloak"
# #         }
# #         tolerations = [
# #           {
# #             key      = "role"
# #             operator = "Equal"
# #             value    = "osdu-istio-keycloak"
# #             effect   = "NoSchedule"
# #           }
# #         ]
# #       }
# #     })
# #   ]
# #   wait    = true
# #   timeout = 600
# #   depends_on = [
# #     helm_release.osdu-ir-istio-base,
# #     kubernetes_namespace.istio-namespace
# #   ]
# # }


# # Deploying the Istio Ingress Gateway 
# resource "helm_release" "istio_ingressgateway" {
#   name = "istio-ingressgateway"
#   /* The Zscaler was blocking this so the tgz files were 
#   /  downloaded to local folder
#   / Use your cognizance for this */
#   # repository = "https://istio-release.storage.googleapis.com/charts"
#   # chart      = "gateway"
#   chart     = "${path.module}/charts/istio-gateway-1.21.0.tgz"
#   namespace = kubernetes_namespace.istio-gateway-namespace.metadata[0].name
#   version   = "1.21.0"

#   values = [
#     yamlencode({

#       image = {
#         repository = "docker.io/istio/proxyv2"
#         tag        = "1.21.0"
#         pullPolicy = "IfNotPresent"
#       }

#       service = {
#         type = "LoadBalancer"
#         ports = [
#           {
#             port       = 80
#             targetPort = 8080
#             name       = "http2"
#           },
#           {
#             port       = 443
#             targetPort = 8443
#             name       = "https"
#           }
#         ]
#       }

#       nodeSelector = {
#         "node-role" = "osdu-istio-keycloak"
#       }

#       tolerations = [
#         {
#           key      = "role"
#           operator = "Equal"
#           value    = "osdu-istio-keycloak"
#           effect   = "NoSchedule"
#         }
#       ]

#     })
#   ]
#   wait    = true
#   timeout = 600
#   depends_on = [
#     helm_release.osdu-ir-istio-base,
#     helm_release.osdu-ir-istio-istiod,
#     kubernetes_namespace.istio-gateway-namespace
#   ]
# }

# # Creating the service gateway
# resource "null_resource" "osdu-ir-service-gateway" {
#   depends_on = [
#     helm_release.istio_ingressgateway,
#     null_resource.update_kubeconfig,
#     null_resource.wait_for_ingressgateway
#   ]

#   provisioner "local-exec" {
#     interpreter = ["PowerShell", "-Command"]
#     command     = <<-EOT
#     @"
# apiVersion: networking.istio.io/v1beta1
# kind: Gateway
# metadata:
#   name: service-gateway
#   namespace: default
# spec:
#   selector:
#     istio: ingressgateway
#   servers:
#     - port:
#         number: 80
#         name: http
#         protocol: HTTP
#       hosts:
#         - osdu.${local.istio_gateway_domain}
# "@ | kubectl apply -f -
#   EOT
#   }
# }







# Create namespace
resource "kubernetes_namespace" "istio-namespace" {
  metadata {
    name = "istio-system"
  }
}

# Create namespace
resource "kubernetes_namespace" "istio-gateway-namespace" {
  metadata {
    name = "istio-gateway"
  }
}

resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "echo 'Updating kubeconfig...' && aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}"
  }

  triggers = {
    cluster_name = var.cluster_name
    region       = var.region
  }
  depends_on = [aws_eks_cluster.osdu-ir-eks-cluster]
}

resource "null_resource" "label_default_namespace" {
  provisioner "local-exec" {
    command = "echo 'Labeling default namespace for Istio sidecar injection...' && kubectl label namespace default istio-injection=enabled --overwrite"
  }

  depends_on = [
    null_resource.update_kubeconfig,
    helm_release.osdu-ir-istio-istiod
  ]
}

# Creating the Istio Base
resource "helm_release" "osdu-ir-istio-base" {
  name      = "osdu-ir-istio-base"
  chart     = "${path.module}/charts/istio-base-1.21.0.tgz"
  namespace = kubernetes_namespace.istio-namespace.metadata[0].name
  version   = "1.21.0"
  
  depends_on = [
    kubernetes_namespace.istio-namespace,
    aws_eks_addon.osdu-ir-csi-addon
  ]
}

# ✅ FIXED: Uncommented and corrected Istiod deployment
resource "helm_release" "osdu-ir-istio-istiod" {
  name      = "osdu-ir-istio-istiod"
  chart     = "${path.module}/charts/istiod-1.21.0.tgz"
  namespace = kubernetes_namespace.istio-namespace.metadata[0].name
  version   = "1.21.0"

  values = [
    yamlencode({
      global = {
        proxy = {
          autoInject = "enabled"
        }
      }
      pilot = {
        nodeSelector = {
          "node-role" = "osdu-istio-keycloak"
        }
        tolerations = [
          {
            key      = "node-role"  # ✅ FIXED: Changed from "role" to "node-role"
            operator = "Equal"
            value    = "osdu-istio-keycloak"
            effect   = "NoSchedule"
          }
        ]
      }
    })
  ]
  wait    = true
  timeout = 600
  depends_on = [
    helm_release.osdu-ir-istio-base,
    kubernetes_namespace.istio-namespace
  ]
}

# Deploying the Istio Ingress Gateway 
resource "helm_release" "istio_ingressgateway" {
  name      = "istio-ingressgateway"
  chart     = "${path.module}/charts/istio-gateway-1.21.0.tgz"
  namespace = kubernetes_namespace.istio-gateway-namespace.metadata[0].name
  version   = "1.21.0"

  values = [
    yamlencode({
      image = {
        repository = "docker.io/istio/proxyv2"
        tag        = "1.21.0"
        pullPolicy = "IfNotPresent"
      }

      service = {
        type = "LoadBalancer"
        ports = [
          {
            port       = 80
            targetPort = 8080
            name       = "http2"
          },
          {
            port       = 443
            targetPort = 8443
            name       = "https"
          }
        ]
      }

      nodeSelector = {
        "node-role" = "osdu-istio-keycloak"
      }

      tolerations = [
        {
          key      = "node-role"  # ✅ FIXED: Changed from "role" to "node-role"
          operator = "Equal"
          value    = "osdu-istio-keycloak"
          effect   = "NoSchedule"
        }
      ]
    })
  ]
  wait    = true
  timeout = 600
  depends_on = [
    helm_release.osdu-ir-istio-base,
    helm_release.osdu-ir-istio-istiod,
    kubernetes_namespace.istio-gateway-namespace
  ]
}

# ✅ FIXED: Converting PowerShell to Linux-compatible bash
resource "null_resource" "osdu-ir-service-gateway" {
  depends_on = [
    helm_release.istio_ingressgateway,
    null_resource.update_kubeconfig
  ]

  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: service-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - osdu.${local.istio_gateway_domain}
EOF
    EOT
  }
}
