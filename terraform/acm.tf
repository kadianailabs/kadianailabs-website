# ─────────────────────────────────────────────────────────
# Optional ACM certificate for the site domain, DNS-validated
# via an existing Route53 hosted zone. Enable with
# create_acm_certificate = true (requires the zone to exist).
# The cert ARN is exported for the Ingress annotation.
# ─────────────────────────────────────────────────────────
data "aws_route53_zone" "this" {
  count        = var.create_acm_certificate ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

resource "aws_acm_certificate" "this" {
  count                     = var.create_acm_certificate ? 1 : 0
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.create_acm_certificate ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  count                   = var.create_acm_certificate ? 1 : 0
  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
