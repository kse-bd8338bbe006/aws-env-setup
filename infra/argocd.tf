##########################
# Helm Provider Configuration #
##########################

provider "helm" {
  kubernetes {
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
}

##########################
# ArgoCD Installation #
##########################

resource "helm_release" "argocd" {
    name             = "argocd"
    repository       = "https://argoproj.github.io/argo-helm"
    chart            = "argo-cd"
    namespace        = "argocd"
    create_namespace = true
    version          = "9.1.4"

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
        extraArgs = [
          "--insecure" # For ALB with SSL termination
        ]
      }
      configs = {
        params = {
          "server.insecure" = true
        }
        cm = {
          "timeout.reconciliation" = "180s"
        }
      }
    })
  ]

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main
  ]
}
