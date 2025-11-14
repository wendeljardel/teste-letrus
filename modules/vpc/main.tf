data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Otimização de custos: 2 AZs em dev (mínimo para Aurora), 3 em prod (alta disponibilidade)
  default_az_count = var.environment == "prod" ? 3 : 2
  azs              = var.azs != null ? var.azs : slice(data.aws_availability_zones.available.names, 0, local.default_az_count)

  # NAT Gateway count: 1 em dev (economia), N em prod (alta disponibilidade)
  nat_gateway_count = var.environment == "prod" ? length(local.azs) : 1
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-igw"
    }
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr, 8, count.index)
  availability_zone = local.azs[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-${count.index + 1}"
      Type = "public"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-${count.index + 1}"
      Type = "private"
    }
  )
}

# Database Subnets (isolated)
resource "aws_subnet" "database" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr, 8, count.index + 20)
  availability_zone = local.azs[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-database-${count.index + 1}"
      Type = "database"
    }
  )
}

# Elastic IPs para Nat Gateway
# Otimizado: 1 em dev, N em prod
resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-eip-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# Nat Gateways
# Otimizado: 1 em dev (economia ~$70/mês), N em prod (alta disponibilidade)
resource "aws_nat_gateway" "main" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nat-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# Route Table para Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-rt"
    }
  )
}

# Route Table Associations para Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Tables para Private Subnets
# Otimizado: Em dev, todas as subnets usam o mesmo NAT Gateway (economia)
resource "aws_route_table" "private" {
  count  = length(local.azs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    # Em dev: todas usam NAT Gateway [0]
    # Em prod: cada subnet usa seu próprio NAT Gateway
    nat_gateway_id = var.environment == "prod" ? aws_nat_gateway.main[count.index].id : aws_nat_gateway.main[0].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-rt-${count.index + 1}"
    }
  )
}

# Route Table Associations para Private Subnets
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Route Table para Database Subnets (sem rotas de saída)
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-database-rt"
    }
  )
}

# Route Table Associations para Database Subnets
resource "aws_route_table_association" "database" {
  count          = length(aws_subnet.database)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-db-subnet-group"
    }
  )
}

# VPC Endpoint para S3 (Gateway - GRÁTIS!)
# Elimina custo de data transfer pelo NAT Gateway para S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  
  # Gateway endpoint associado às route tables
  route_table_ids = concat(
    aws_route_table.private[*].id,
    [aws_route_table.database.id],
    [aws_route_table.public.id]
  )

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-s3-endpoint"
      Type = "Gateway"
      Cost = "FREE"
    }
  )
}

# Data source para região atual
data "aws_region" "current" {}

# VPC Endpoint para Glue (Interface - ~$7/mês, mas economiza data transfer via NAT)
# Somente criar se environment = prod para economizar em dev
resource "aws_vpc_endpoint" "glue" {
  count = var.environment == "prod" ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.glue"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  
  subnet_ids = aws_subnet.private[*].id
  
  security_group_ids = [aws_security_group.vpc_endpoints[0].id]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-glue-endpoint"
      Type = "Interface"
    }
  )
}

# Security Group para VPC Endpoints (interface)
resource "aws_security_group" "vpc_endpoints" {
  count = var.environment == "prod" ? 1 : 0

  name        = "${var.name_prefix}-vpc-endpoints-sg"
  description = "Security group para VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc-endpoints-sg"
    }
  )
}

