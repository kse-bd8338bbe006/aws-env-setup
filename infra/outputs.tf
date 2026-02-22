output "cd_user_access_key_id" {
  description = "Access key ID for CD user"
  value       = aws_iam_access_key.cd.id
}

output "cd_user_access_key_secret" {
  description = "Access key secret for CD user"
  value       = aws_iam_access_key.cd.secret
  sensitive   = true
}

##########################
# EKS Outputs            #
##########################

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "eks_cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "eks_node_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  value       = aws_iam_role.eks_nodes.arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS"
  value       = aws_iam_role.external_dns.arn
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = aws_route53_zone.main.name
}

##########################
# ArgoCD Outputs         #
##########################

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = helm_release.argocd.namespace
}

output "argocd_server_access_command" {
  description = "Command to access ArgoCD server via port-forward"
  value       = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

output "argocd_admin_password_command" {
  description = "Command to get ArgoCD initial admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
}

output "argocd_login_info" {
  description = "ArgoCD login information"
  value = <<-EOT
    Username: admin
    Password: Run this command:
      kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
    
    Access ArgoCD:
      kubectl port-forward svc/argocd-server -n argocd 8080:443
      Then open: https://localhost:8080
  EOT
}

##########################
# ALB Controller Outputs #
##########################

output "alb_controller_installed" {
  description = "AWS Load Balancer Controller installation status"
  value       = "Installed via Helm in kube-system namespace"
}

output "argocd_url" {
  description = "ArgoCD URL (will be available after ALB is provisioned)"
  value       = "https://argocd.${var.domain_name}"
}

output "argocd_alb_info" {
  description = "Check ArgoCD ALB status"
  value       = "kubectl get ingress -n argocd argocd-server-ingress"
}

##########################
# ACM Certificate Outputs #
##########################

output "acm_certificate_arn" {
  description = "ARN of the wildcard ACM certificate"
  value       = aws_acm_certificate.main.arn
}

output "acm_certificate_domain" {
  description = "Domain name of the certificate"
  value       = aws_acm_certificate.main.domain_name
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = aws_acm_certificate.main.status
}

##########################
# Monitoring Outputs     #
##########################

output "prometheus_namespace" {
  description = "Namespace where Prometheus is installed"
  value       = helm_release.kube_prometheus_stack.namespace
}

output "grafana_access_command" {
  description = "Command to access Grafana via port-forward"
  value       = "kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
}

output "grafana_login_info" {
  description = "Grafana login information"
  value = <<-EOT
    Username: admin
    Password: admin (change this in production!)
    
    Access Grafana:
      kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
      Then open: http://localhost:3000
  EOT
}

output "prometheus_access_command" {
  description = "Command to access Prometheus via port-forward"
  value       = "kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090"
}

output "alertmanager_access_command" {
  description = "Command to access AlertManager via port-forward"
  value       = "kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093"
}
