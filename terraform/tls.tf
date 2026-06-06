# ==========================================
# CERT-MANAGER INSTALLATION
# ==========================================
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.16.0"

  values = [<<-YAML
    installCRDs: true
    startupapicheck:  
      enabled: false 
  YAML
  ]

  depends_on = [module.eks]
}

# 30s wait time for CRDs to fully register before creating ClusterIssuer
resource "time_sleep" "wait_for_cert_manager" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# ==========================================
# ENCRYPT CLUSTER ISSUER
# ==========================================
resource "null_resource" "cluster_issuer" {
  depends_on = [time_sleep.wait_for_cert_manager]

  provisioner "local-exec" {
    command = <<-BASH
      kubectl apply -f - <<'YAML'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: lilsharkszn@techie.com
    privateKeySecretRef:
      name: letsencrypt-prod-private-key
    solvers:
    - http01:
        ingress:
          ingressClassName: alb
          ingressTemplate:
            metadata:
              annotations:
                alb.ingress.kubernetes.io/scheme: internet-facing
                alb.ingress.kubernetes.io/target-type: ip
                alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
YAML
    BASH
  }

  triggers = {
    always_run = timestamp()
  }
}
