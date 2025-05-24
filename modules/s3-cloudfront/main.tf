# # Create the S3 bucket to host the website
# resource "aws_s3_bucket" "website" {
#   bucket         = var.bucket_name
#   force_destroy  = true

#   # Enable versioning for better safety
#   versioning {
#     enabled = true
#   }

#   # Enable server-side encryption with AWS managed key (AES256)
#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }
# }

# # Block all public access at the bucket level
# resource "aws_s3_bucket_public_access_block" "block_public_access" {
#   bucket                  = aws_s3_bucket.website.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# resource "aws_s3_bucket_website_configuration" "website" {
#   bucket = aws_s3_bucket.website.bucket

#   index_document {
#     suffix = "index.html"
#   }
# }

# # Bucket policy to deny insecure transport and allow only CloudFront via OAC
# resource "aws_s3_bucket_policy" "deny_public_access" {
#   bucket = aws_s3_bucket.website.id
#   policy = data.aws_iam_policy_document.s3_bucket_policy.json
# }

# data "aws_iam_policy_document" "s3_bucket_policy" {
#   statement {
#     sid    = "DenyInsecureTransport"
#     effect = "Deny"

#     principals {
#       type        = "AWS"
#       identifiers = ["*"]
#     }

#     actions   = ["s3:GetObject"]
#     resources = ["${aws_s3_bucket.website.arn}/*"]

#     condition {
#       test     = "Bool"
#       variable = "aws:SecureTransport"
#       values   = ["false"]
#     }
#   }

#   statement {
#     sid    = "AllowCloudFrontServicePrincipal"
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["cloudfront.amazonaws.com"]
#     }

#     actions   = ["s3:GetObject"]
#     resources = ["${aws_s3_bucket.website.arn}/*"]

#     # This must match the OAC's ARN, so using cloudfront distribution ARN is fine here
#     condition {
#       test     = "StringEquals"
#       variable = "AWS:SourceArn"
#       values   = [aws_cloudfront_distribution.cdn.arn]
#     }
#   }
# }

# # CloudFront Origin Access Control (OAC) to securely access S3 bucket
# resource "aws_cloudfront_origin_access_control" "oac" {
#   name                              = "s3-oac-nandha-v2"
#   description                       = "OAC for CloudFront to access S3"
#   origin_access_control_origin_type = "s3"
#   signing_behavior                  = "always"
#   signing_protocol                  = "sigv4"
# }

# # CloudFront distribution setup
# resource "aws_cloudfront_distribution" "cdn" {
#   enabled             = true
#   default_root_object = "index.html"
#   comment             = "CDN for static website"

#   origin {
#     domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
#     origin_id                = "s3-origin"
#     origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
#   }

#   default_cache_behavior {
#     target_origin_id       = "s3-origin"
#     viewer_protocol_policy = "redirect-to-https"
#     allowed_methods        = ["GET", "HEAD"]
#     cached_methods         = ["GET", "HEAD"]

#     forwarded_values {
#       query_string = false
#       cookies {
#         forward = "none"
#       }
#     }
#   }

#   viewer_certificate {
#     cloudfront_default_certificate = true
#   }

#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }
# }


# Create the S3 bucket to host the website
resource "aws_s3_bucket" "website" {
  bucket        = var.bucket_name
  force_destroy = true

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Block all public access at the bucket level
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.bucket

  index_document {
    suffix = "index.html"
  }
}

# Bucket policy to deny insecure transport and allow only CloudFront via OAC
resource "aws_s3_bucket_policy" "deny_public_access" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

# WAFv2 Web ACL to protect CloudFront
resource "aws_wafv2_web_acl" "web_acl" {
  name        = "static-site-waf"
  description = "WAF for CloudFront static site"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "staticSiteWAF"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
}

# CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-oac-nandha-v2"
  description                       = "OAC for CloudFront to access S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution setup
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "CDN for static website"

  web_acl_id = aws_wafv2_web_acl.web_acl.arn

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
