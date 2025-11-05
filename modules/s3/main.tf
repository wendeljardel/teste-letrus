# Bucket S3 para dados brutos
resource "aws_s3_bucket" "raw" {
  bucket = "${var.name_prefix}-raw-${var.suffix}"

  tags = merge(
    var.tags,
    {
      Name        = "${var.name_prefix}-raw-${var.suffix}"
      BucketType  = "raw-data"
    }
  )
}

resource "aws_s3_bucket_versioning" "raw" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.raw.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  count  = var.enable_lifecycle ? 1 : 0
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = var.lifecycle_days_to_ia
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = var.lifecycle_days_to_glacier
      storage_class = "GLACIER"
    }
  }
}

# Bucket S3 para dados processados
resource "aws_s3_bucket" "processed" {
  bucket = "${var.name_prefix}-processed-${var.suffix}"

  tags = merge(
    var.tags,
    {
      Name        = "${var.name_prefix}-processed-${var.suffix}"
      BucketType  = "processed-data"
    }
  )
}

resource "aws_s3_bucket_versioning" "processed" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.processed.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "processed" {
  count  = var.enable_lifecycle ? 1 : 0
  bucket = aws_s3_bucket.processed.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = var.lifecycle_days_to_ia
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = var.lifecycle_days_to_glacier
      storage_class = "GLACIER"
    }
  }
}

# Bucket S3 para scripts do Glue
resource "aws_s3_bucket" "scripts" {
  bucket = "${var.name_prefix}-scripts-${var.suffix}"

  tags = merge(
    var.tags,
    {
      Name        = "${var.name_prefix}-scripts-${var.suffix}"
      BucketType  = "glue-scripts"
    }
  )
}

resource "aws_s3_bucket_versioning" "scripts" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.scripts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "scripts" {
  bucket = aws_s3_bucket.scripts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "scripts" {
  bucket = aws_s3_bucket.scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

