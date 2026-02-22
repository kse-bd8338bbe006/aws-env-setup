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

# Output nameservers for domain configuration
output "route53_nameservers" {
  description = "Nameservers for the Route53 hosted zone - configure these in your domain registrar"
  value       = aws_route53_zone.main.name_servers
}
