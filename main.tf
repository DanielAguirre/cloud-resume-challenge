provider "aws" {
    region ="us-east-1"
}

variable "bucketName" {}

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_s3_bucket" "resume-challenge" {
    bucket = var.bucketName

    tags = {
        Name = "resume challenge"
        Environment= "Dev"
    }
}

resource "aws_s3_bucket_acl" "resume-challenge-acl" {
    bucket = aws_s3_bucket.resume-challenge.id
    acl = "private"
}

#  Website Configuration

resource "aws_s3_bucket_website_configuration" "resume-challenge" {
    bucket = aws_s3_bucket.resume-challenge.bucket

    index_document {
        suffix = "index.html"
    }
}


# Policy access

resource "aws_s3_bucket_policy" "resume-challenge-policy" {
    bucket = aws_s3_bucket.resume-challenge.id
    policy = templatefile("s3-policy.json", { bucket = var.bucketName})
}


resource "aws_cloudfront_origin_access_control" "resume-challenge-cloudfront-access-control" {
  name                              = "example"
  description                       = "Example Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

#  CloudFront Distribution
resource "aws_cloudfront_distribution" "resume-challenge-s3-distribution" {
    origin {
        domain_name = aws_s3_bucket.resume-challenge.bucket_regional_domain_name
        origin_access_control_id = aws_cloudfront_origin_access_control.resume-challenge-cloudfront-access-control.id
        origin_id                = local.s3_origin_id
    }

    enabled             = true
    is_ipv6_enabled     = true
    comment             = "Some comment"
    default_root_object = "index.html"

    logging_config {
        include_cookies = false
        bucket          = "${var.bucketName}.s3.amazonaws.com"
        prefix          = "myprefix"
    }

    # aliases = ["mysite.example.com", "yoursite.example.com"]

    default_cache_behavior {
        allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id

        forwarded_values {
        query_string = false

        cookies {
            forward = "none"
        }
        }

        viewer_protocol_policy = "allow-all"
        min_ttl                = 0
        default_ttl            = 3600
        max_ttl                = 86400
    }

    # Cache behavior with precedence 0
    ordered_cache_behavior {
        path_pattern     = "/content/immutable/*"
        allowed_methods  = ["GET", "HEAD", "OPTIONS"]
        cached_methods   = ["GET", "HEAD", "OPTIONS"]
        target_origin_id = local.s3_origin_id

        forwarded_values {
        query_string = false
        headers      = ["Origin"]

        cookies {
            forward = "none"
        }
        }

        min_ttl                = 0
        default_ttl            = 86400
        max_ttl                = 31536000
        compress               = true
        viewer_protocol_policy = "redirect-to-https"
    }

    # Cache behavior with precedence 1
    ordered_cache_behavior {
        path_pattern     = "/content/*"
        allowed_methods  = ["GET", "HEAD", "OPTIONS"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id

        forwarded_values {
        query_string = false

        cookies {
            forward = "none"
        }
        }

        min_ttl                = 0
        default_ttl            = 3600
        max_ttl                = 86400
        compress               = true
        viewer_protocol_policy = "redirect-to-https"
    }

    price_class = "PriceClass_200"

    restrictions {
        geo_restriction {
        restriction_type = "whitelist"
        locations        = ["MX","US", "CA", "GB", "DE"]
        }
    }

    tags = {
        Name = "resume-challoenge-cloudfront"
        Environment = "Dev"
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }

}

output "aws_cloudfront_distribution" {
    value = aws_cloudfront_distribution.resume-challenge-s3-distribution
}
