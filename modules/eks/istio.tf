# #########################################################################
# # STEP 1: Create Istio System Namespace
# #########################################################################
# resource "kubernetes_namespace" "istio_system" {
#   metadata {
#     name = "istio-system"
#     labels = {
#       name                 = "istio-system"
#       "istio-injection"   = "disabled"
#     }
#   }
  
#   depends_on = [
#     aws_eks_cluster.eks,
#     aws_eks_node_group.node-grp
#   ]
# }

# #########################################################################
# # STEP 2: Install Istio Base (CRDs and Cluster Roles)
# #########################################################################
# resource "helm_release" "istio_base" {
#   name       = "istio-base"
#   repository = "https://istio-release.storage.googleapis.com/charts"
#   chart      = "base"
#   namespace  = kubernetes_namespace.istio_system.metadata[0].name
#   version    = var.istio_version # Latest stable, meets OSDU requirement (1.17.2+)

#   set {
#     name  = "global.istioNamespace"
#     value = "istio-system"
#   }
  
#   depends_on = [kubernetes_namespace.istio_system]
# }

# #########################################################################
# # STEP 3: Install Istio Control Plane (Istiod)
# #########################################################################
# resource "helm_release" "istiod" {
#   name       = "istiod"
#   repository = "https://istio-release.storage.googleapis.com/charts"
#   chart      = "istiod"
#   namespace  = kubernetes_namespace.istio_system.metadata[0].name
#   version    = var.istio_version
  
#   set {
#     name  = "telemetry.enabled"
#     value = "true"
#   }

#   set {
#     name  = "global.istioNamespace"
#     value = "istio-system"
#   }

#   set {
#     name  = "meshConfig.ingressService"
#     value = "istio-gateway"
#   }

#   set {
#     name  = "meshConfig.ingressSelector"
#     value = "gateway"
#   }

#   depends_on = [helm_release.istio_base]
# }

# # #########################################################################
# # # STEP 4: Install Istio Ingress Gateway 
# # #########################################################################
# # resource "helm_release" "istio_ingress_gateway" {
# #   name             = "istio-ingressgateway"
# #   repository       = "https://istio-release.storage.googleapis.com/charts"
# #   chart            = "gateway"
# #   namespace        = kubernetes_namespace.istio_system.metadata[0].name
# #   version          = var.istio_version

# #   depends_on = [helm_release.istiod, helm_release.istio_base]
# # }



# #########################################################################
# # STEP 4: Install Istio Ingress Gateway (Alternative)
# #########################################################################
# resource "helm_release" "istio_ingress_gateway" {
#   name             = "istio-ingressgateway"
#   repository       = "https://istio-release.storage.googleapis.com/charts"
#   chart            = "gateway"
#   namespace        = kubernetes_namespace.istio_system.metadata[0].name
#   version          = var.istio_version
#   timeout          = 900
  
# #   # Use set blocks instead of values for more control
# #   set {
# #     name  = "image.repository"
# #     value = "istio/proxyv2"
# #   }
  
# #   set {
# #     name  = "image.tag"
# #     value = var.istio_version
# #   }
  
#   set {
#     name  = "service.type"
#     value = "LoadBalancer"
#   }
  
# #   set {
# #     name  = "resources.requests.cpu"
# #     value = "50m"
# #   }
  
# #   set {
# #     name  = "resources.requests.memory"
# #     value = "64Mi"
# #   }

#   depends_on = [
#     helm_release.istiod,
#     helm_release.istio_base
#   ]
# }



###########################################################################


#########################################################################
# STEP 1: Create Istio System Namespace
#########################################################################
resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
    labels = {
      name                 = "istio-system"
      "istio-injection"   = "disabled"
    }
  }
  
  depends_on = [
    aws_eks_cluster.eks,
    aws_eks_node_group.node-grp
  ]
}

#########################################################################
# STEP 2: Install Istio Base (CRDs and Cluster Roles)
#########################################################################
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = kubernetes_namespace.istio_system.metadata[0].name
  version    = var.istio_version # Latest stable, meets OSDU requirement (1.17.2+)

  set {
    name  = "global.istioNamespace"
    value = "istio-system"
  }
  
  depends_on = [kubernetes_namespace.istio_system]
}

#########################################################################
# STEP 3: Install Istio Control Plane (Istiod)
#########################################################################
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = kubernetes_namespace.istio_system.metadata[0].name
  version    = var.istio_version
  

  set {
    name  = "telemetry.enabled"
    value = "true"
  }

  set {
    name  = "global.istioNamespace"
    value = "istio-system"
  }

  set {
    name  = "meshConfig.ingressService"
    value = "istio-gateway"
  }

  set {
    name  = "meshConfig.ingressSelector"
    value = "gateway"
  }

  depends_on = [helm_release.istio_base]
}



#########################################################################
# STEP 4: Install Istio Ingress Gateway (FIXED VERSION)
#########################################################################


resource "helm_release" "istio-ingress" {
  name             = "istio-ingress"
  namespace        = "istio-ingress"
  create_namespace = true
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "gateway"
  version          = "1.25.0"

  force_update  = true
  recreate_pods = true
  description   = "force update 1"
  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "service.externalTrafficPolicy"
    value = "Local"
  }
  

  timeout = 1200
  wait    = true
  depends_on = [
    helm_release.istio_base,
    helm_release.istiod,
  ]
}