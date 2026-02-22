##########################
# Default StorageClass Configuration #
##########################

# Set gp2 as the default StorageClass
resource "kubernetes_annotations" "default_storageclass" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  
  metadata {
    name = "gp2"
  }
  
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "true"
  }

  force = true

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main
  ]
}
