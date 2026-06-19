# ==========================================
# CERT-MANAGER CERTIFICATE RESOURCE
# Applied via kubectl after cluster is ready
# kubernetes_manifest cannot be used during
# initial plan — no cluster exists yet
# ==========================================

resource "null_resource" "retail_store_certificate" {
  depends_on = [null_resource.cluster_issuer]

  provisioner "local-exec" {
    command = <<-BASH
      kubectl apply -f - <<'YAML'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: retail-store-tls
  namespace: retail-app
spec:
  secretName: retail-store-tls
  duration: 2160h
  renewBefore: 720h
  commonName: altsoe0254423.ddns.net
  dnsNames:
    - altsoe0254423.ddns.net
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
YAML
    BASH
  }

  triggers = {
    always_run = timestamp()
  }
}
