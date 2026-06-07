# ==========================================
# CERT-MANAGER CERTIFICATE RESOURCE
# Issues the actual TLS certificate from Let's Encrypt
# ==========================================

resource "kubernetes_manifest" "retail_store_certificate" {
  depends_on = [null_resource.cluster_issuer]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "retail-store-tls"
      namespace = "retail-app"
    }
    spec = {
      secretName = "retail-store-tls"
      duration   = "2160h"    # 90 days
      renewBefore = "720h"     # 30 days before expiry
      commonName = "altsoe0254423.ddns.net"
      dnsNames = [
        "altsoe0254423.ddns.net"
      ]
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
    }
  }
}
