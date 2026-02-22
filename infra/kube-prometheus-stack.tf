##########################
# Kube-Prometheus-Stack Installation #
##########################

# Install kube-prometheus-stack via Helm
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "55.5.0"
  
  create_namespace = true

  values = [
    yamlencode({
      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          retention = "30d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
          resources = {
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }

      # Grafana configuration
      grafana = {
        enabled = true
        adminPassword = "admin" # Change this in production!
        
        service = {
          type = "ClusterIP"
        }

        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }

        # Persistence for Grafana dashboards
        persistence = {
          enabled = true
          size    = "5Gi"
        }
      }

      # AlertManager configuration
      alertmanager = {
        enabled = true
        
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "5Gi"
                  }
                }
              }
            }
          }
          resources = {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }
      }

      # Node Exporter configuration
      nodeExporter = {
        enabled = true
      }

      # Kube State Metrics configuration
      kubeStateMetrics = {
        enabled = true
      }

      # Default rules
      defaultRules = {
        create = true
        rules = {
          alertmanager           = true
          etcd                   = true
          configReloaders        = true
          general                = true
          k8s                    = true
          kubeApiserver          = true
          kubeApiserverAvailability = true
          kubeApiserverSlos      = true
          kubelet                = true
          kubeProxy              = true
          kubePrometheusGeneral  = true
          kubePrometheusNodeRecording = true
          kubernetesApps         = true
          kubernetesResources    = true
          kubernetesStorage      = true
          kubernetesSystem       = true
          kubeScheduler          = true
          kubeStateMetrics       = true
          network                = true
          node                   = true
          nodeExporterAlerting   = true
          nodeExporterRecording  = true
          prometheus             = true
          prometheusOperator     = true
        }
      }
    })
  ]

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main,
    aws_eks_node_group.additional
  ]
}
