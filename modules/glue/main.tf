locals {
  database_name     = "${var.name_prefix}-catalog-db"
  connection_name   = "${var.name_prefix}-aurora-connection"
  jdbc_prefix       = var.aurora_engine == "postgresql" ? "postgresql" : "mysql"
}

# Glue Data Catalog Database
resource "aws_glue_catalog_database" "main" {
  name        = local.database_name
  description = "Glue Data Catalog database para ${var.name_prefix}"

  parameters = {
    "classification" = "json"
  }

  tags = merge(
    var.tags,
    {
      Name = local.database_name
    }
  )
}

# Glue Connection para Aurora
resource "aws_glue_connection" "aurora" {
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:${local.jdbc_prefix}://${var.aurora_endpoint}:${var.aurora_port}/${var.aurora_database_name}"
    JDBC_ENFORCE_SSL    = "true"
    PASSWORD            = var.aurora_master_password
    USERNAME            = var.aurora_master_username
  }

  name = local.connection_name

  physical_connection_requirements {
    availability_zone      = data.aws_subnet.glue_subnet.availability_zone
    security_group_id_list = [var.glue_connection_security_group_id]
    subnet_id              = length(var.database_subnet_ids) > 0 ? var.database_subnet_ids[0] : ""
  }

  tags = merge(
    var.tags,
    {
      Name = local.connection_name
    }
  )
}

# Data source para obter a AZ da subnet automaticamente
data "aws_subnet" "glue_subnet" {
  id = length(var.database_subnet_ids) > 0 ? var.database_subnet_ids[0] : ""
}

# Glue Jobs
resource "aws_glue_job" "main" {
  for_each = var.jobs

  name     = "${var.name_prefix}-${each.key}"
  role_arn = var.glue_role_arn

  command {
    script_location = replace(
      replace(
        replace(each.value.script_location, "PLACEHOLDER", var.suffix),
        "${var.name_prefix}-scripts-${var.suffix}",
        "s3://${var.s3_scripts_bucket}"
      ),
      "s3://s3://",
      "s3://"
    )
    python_version  = each.value.python_version
  }

  glue_version = each.value.glue_version

  default_arguments = merge(
    {
      "--TempDir"                        = "s3://${var.s3_processed_bucket}/temp/"
      "--enable-metrics"                 = "true"
      "--enable-continuous-cloudwatch-log" = "true"
      "--enable-spark-ui"                = "true"
      "--spark-event-logs-path"          = "s3://${var.s3_processed_bucket}/spark-logs/"
      "--job-bookmark-option"            = "job-bookmark-enable"
      "--job-language"                   = "python"
    },
    # Parâmetros específicos para jobs ETL
    contains(["etl-pipeline", "etl-raw-to-processed"], each.key) ? {
      "--S3_RAW_BUCKET"           = var.s3_raw_bucket
      "--S3_PROCESSED_BUCKET"     = var.s3_processed_bucket
      "--AURORA_CONNECTION_NAME"  = local.connection_name
      "--AURORA_DATABASE_NAME"    = var.aurora_database_name
    } : {}
  )

  execution_property {
    max_concurrent_runs = 1
  }

  max_capacity = each.value.max_capacity
  timeout      = each.value.timeout
  
  connections = contains(["etl-pipeline", "etl-raw-to-processed"], each.key) ? [aws_glue_connection.aurora.name] : []

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-${each.key}"
    }
  )
}

# Glue Crawlers
resource "aws_glue_crawler" "main" {
  for_each = var.crawlers

  name          = "${var.name_prefix}-${each.key}"
  role          = var.crawler_role_arn
  database_name = each.value.database_name != "" ? each.value.database_name : aws_glue_catalog_database.main.name

  # Substituir placeholders nos paths S3 pelos nomes reais dos buckets
  dynamic "s3_target" {
    for_each = each.value.s3_paths
    content {
      path = replace(
        replace(
          replace(s3_target.value, "PLACEHOLDER", var.suffix),
          "s3://${var.name_prefix}-raw-${var.suffix}", 
          "s3://${var.s3_raw_bucket}"
        ),
        "s3://${var.name_prefix}-processed-${var.suffix}",
        "s3://${var.s3_processed_bucket}"
      )
    }
  }

  schema_change_policy {
    update_behavior = try(each.value.schema_change_policy.update_behavior, "UPDATE_IN_DATABASE")
    delete_behavior = try(each.value.schema_change_policy.delete_behavior, "LOG")
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-${each.key}"
    }
  )
}
