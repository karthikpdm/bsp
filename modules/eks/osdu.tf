

# Get Istio LoadBalancer information
data "kubernetes_service" "istio_ingress" {
  metadata {
    name      = "istio-ingress"
    namespace = "istio-gateway"
  }
}

locals {
  istio_hostname = try(data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.hostname, "")
}

################################################################################################################

# OSDU Baremetal Helm Installation


resource "helm_release" "osdu-baremetal" {
  name      = "osdu-baremetal"
  chart     = "${path.module}/helm_osdu/osdu-gc-baremetal"
  version   = "0.27.2"
  namespace = "default"

  dependency_update = true

  # Increased timeout for complex OSDU deployment
  timeout = 1800  # 30 minutes (OSDU can take 15-20 minutes to deploy)
  
  # Enable atomic deployment (rollback on failure)
  atomic = true
  
  # Wait for all resources to be ready
  wait = true

  lifecycle {
    ignore_changes = [description]
  }

  values = [
    file("${path.module}/helm_osdu/custom-values.yaml")
  ]

  depends_on = [
    # Ensure Istio is fully installed and configured
    helm_release.istio_base,
    helm_release.istiod,
    helm_release.istio_ingress,
    
    # Ensure default namespace is labeled for sidecar injection
    null_resource.label_default_namespace,
    
    # Ensure Istio ingress service is available
    data.kubernetes_service.istio_ingress
  ]
}


###############################################################################################################

# resource "helm_release" "osdu_baremetal" {
#   name       = "osdu-baremetal"
#   repository = "oci://community.opengroup.org:5555/osdu/platform/deployment-and-operations/infra-gcp-provisioning/gc-helm"
#   chart      = "osdu-gc-baremetal"
#   namespace  = "default"
#   timeout    = 1800  # 30 minutes
#   wait       = true

#   # This reads your custom-values.yaml file
#   # Use the custom-values.yaml file from the same directory as this tf file
#   values = [
#     file("${path.module}/helm_osdu/custom-values.yaml")
#   ]

# }




