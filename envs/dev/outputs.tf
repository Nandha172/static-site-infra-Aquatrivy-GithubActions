output "cloudfront_domain_name" {
  value       = module.static-site.cloudfront_domain_name
  description = "Public URL for accessing the static site via CloudFront"
}

output "cloudfront_distribution_id" {
  value       = module.static-site.cloudfront_distribution_id
  description = "CloudFront distribution ID for cache invalidation"
}
