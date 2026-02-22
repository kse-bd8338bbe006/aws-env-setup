##########################
# ArgoCD Ingress Configuration #
##########################

# Kubernetes provider for creating Ingress
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.main.name,
      "--region",
      data.aws_region.current.name
    ]
  }
}

# ArgoCD Ingress with ALB
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-server-ingress"
    namespace = "argocd"
    
    annotations = {
      "alb.ingress.kubernetes.io/scheme"              = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"         = "ip"
      "alb.ingress.kubernetes.io/backend-protocol"    = "HTTPS"
      "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/healthcheck-path"    = "/healthz"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTPS"
      "alb.ingress.kubernetes.io/certificate-arn"     = aws_acm_certificate.main.arn
      "alb.ingress.kubernetes.io/ssl-redirect"        = "443"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = "argocd.${var.domain_name}"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "argocd-server"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate_validation.main
  ]
}
