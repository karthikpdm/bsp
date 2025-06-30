# This form is used for  * Configure **Istio Gateway** to expose OSDU APIs via public internet (load balancer)

resource "kubernetes_manifest" "osdu-ir-gateway" {
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = "service-gateway" # Must match the gateway name in your Helm-created VirtualServices
      namespace = "default"         # Must match VirtualService namespace
    }

    spec = {
      selector = {
        app = "osdu-ir-istio-gateway" # Matches your running gateway pod
      }

      servers = [
        {
          port = {
            number   = 80
            name     = "http"
            protocol = "HTTP"
          }
          hosts = ["*"]
        }
      ]
    }
  }

  depends_on = [helm_release.osdu-ir-istio-gateway]
}

