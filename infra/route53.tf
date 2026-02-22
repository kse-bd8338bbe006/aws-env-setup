##########################
# Route53 Configuration #
##########################

# Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = "${local.prefix}-hosted-zone"
  }
}

# CNAME record for EKS API endpoint
resource "aws_route53_record" "eks_api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "eks.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300

  records = [replace(aws_eks_cluster.main.endpoint, "https://", "")]

  depends_on = [aws_eks_cluster.main]
}

# Output nameservers for domain configuration
output "route53_nameservers" {
  description = "Nameservers for the Route53 hosted zone - configure these in your domain registrar"
  value       = aws_route53_zone.main.name_servers
}
