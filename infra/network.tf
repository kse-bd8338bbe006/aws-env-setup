##########################
# Network infrastructure #
##########################

resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  lifecycle {
    create_before_destroy = false
  }
}

#########################################################
# Internet Gateway needed for inbound access to the ALB #
# and outbound access from the private subnets  #
#########################################################
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  lifecycle {
    create_before_destroy = false
  }

  tags = {
    Name = "${local.prefix}-main"
  }
}

##################################################
# Public subnets for load balancer public access #
##################################################
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_region.current.name}a"

  tags = {
    Name = "${local.prefix}-public-a"
  }
}

resource "aws_route_table" "public_a" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-public-a"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_a.id
}

resource "aws_route" "public_internet_access_a" {
  route_table_id         = aws_route_table.public_a.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}


resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_region.current.name}b"

  tags = {
    Name = "${local.prefix}-public-b"
  }
}

resource "aws_route_table" "public_b" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-public-b"
  }
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_b.id
}

resource "aws_route" "public_internet_access_b" {
  route_table_id         = aws_route_table.public_b.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Private Subnets for internal access only 

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.10.0/24"
  availability_zone = "${data.aws_region.current.name}a"

  tags = {
    Name = "${local.prefix}-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.11.0/24"
  availability_zone = "${data.aws_region.current.name}b"

  tags = {
    Name = "${local.prefix}-private-b"
  }
}
## Endpoints to allow access to CloudWatch / Systems Manager / S3 from private network

resource "aws_security_group" "endpoint_access" {
  description = "Access to endpoints"
  name        = "${local.prefix}-endpoint-access"
  vpc_id      = aws_vpc.main.id

  ingress {
    cidr_blocks = [aws_vpc.main.cidr_block]
    from_port   = 443 # TODO: is it correct port?
    to_port     = 443
    protocol    = "tcp"
  }
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  security_group_ids = [
    aws_security_group.endpoint_access.id
  ]

  tags = {
    Name = "${local.prefix}-cloudwatch-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  security_group_ids = [
    aws_security_group.endpoint_access.id
  ]

  tags = {
    Name = "${local.prefix}-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  security_group_ids = [
    aws_security_group.endpoint_access.id
  ]

  tags = {
    Name = "${local.prefix}-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_vpc.main.default_route_table_id
  ]
  tags = {
    Name = "${local.prefix}-s3-endpoint"
  }
}

##########################
# NAT Gateway for private subnet outbound access
##########################

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_a" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${local.prefix}-nat-eip-a"
  }
}

# NAT Gateway in public subnet
resource "aws_nat_gateway" "ngw_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [aws_internet_gateway.main]

  lifecycle {
    create_before_destroy = false
  }

  tags = {
    Name = "${local.prefix}-nat-gateway-a"
  }
}

# Route table for private subnets
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-private-a"
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-private-b"
  }
}

# Associate route tables with private subnets
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

# Route for private subnet internet access through NAT Gateway
resource "aws_route" "private_internet_access_a" {
  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw_a.id
}

resource "aws_route" "private_internet_access_b" {
  route_table_id         = aws_route_table.private_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw_a.id
}