terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

# Existing public subnets in different Availability Zones
data "aws_subnet" "public_a" {
  id = "subnet-002d1c6a32cfcb484"
}

data "aws_subnet" "public_c" {
  id = "subnet-08e18ce318fb6158a"
}

# Private subnets for application and database tiers
resource "aws_subnet" "app_a" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = var.app_subnet_a_cidr
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false

  tags = {
    Name    = "TravelMemory-App-Private-A"
    Project = "TravelMemory"
  }
}

resource "aws_subnet" "app_c" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = var.app_subnet_c_cidr
  availability_zone       = "ap-south-1c"
  map_public_ip_on_launch = false

  tags = {
    Name    = "TravelMemory-App-Private-C"
    Project = "TravelMemory"
  }
}

resource "aws_subnet" "database" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = var.database_subnet_cidr
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = false

  tags = {
    Name    = "TravelMemory-Database-Private"
    Project = "TravelMemory"
  }
}

# NAT Gateway for outbound internet access from private subnets
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "TravelMemory-NAT-EIP"
    Project = "TravelMemory"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.aws_subnet.public_a.id

  depends_on = [aws_eip.nat]

  tags = {
    Name    = "TravelMemory-NAT"
    Project = "TravelMemory"
  }
}

resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name    = "TravelMemory-Private-RT"
    Project = "TravelMemory"
  }
}

resource "aws_route_table_association" "app_a" {
  subnet_id      = aws_subnet.app_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app_c" {
  subnet_id      = aws_subnet.app_c.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  subnet_id      = aws_subnet.database.id
  route_table_id = aws_route_table.private.id
}

# Security group for the public load balancer
resource "aws_security_group" "alb" {
  name_prefix = "travelmemory-alb-"
  description = "Public HTTP access to TravelMemory"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Public HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "TravelMemory-ALB-SG"
    Project = "TravelMemory"
  }
}

# Temporary administration jump host
resource "aws_security_group" "jump" {
  name_prefix = "travelmemory-jump-"
  description = "Restricted SSH administration"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from administrator IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "TravelMemory-Jump-SG"
    Project = "TravelMemory"
  }
}

# Application instances accept HTTP only from the ALB.
# SSH is restricted to the jump host.
resource "aws_security_group" "app" {
  name_prefix = "travelmemory-app-"
  description = "Private application tier"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "SSH from jump host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jump.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "TravelMemory-App-SG"
    Project = "TravelMemory"
  }
}

# MongoDB accepts database traffic from the application tier only.
# SSH administration is permitted from the jump host.
resource "aws_security_group" "database" {
  name_prefix = "travelmemory-db-"
  description = "Private MongoDB tier"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "MongoDB from application instances"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "SSH from jump host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jump.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "TravelMemory-Database-SG"
    Project = "TravelMemory"
  }
}

# Temporary public jump host for Ansible administration
resource "aws_instance" "jump" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.jump.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name    = "TravelMemory-Jump"
    Project = "TravelMemory"
  }
}

# Application instance in Availability Zone A
resource "aws_instance" "app_a" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.app_a.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = false

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name    = "TravelMemory-App-A"
    Project = "TravelMemory"
  }
}

# Application instance in Availability Zone C
resource "aws_instance" "app_c" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.app_c.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = false

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name    = "TravelMemory-App-C"
    Project = "TravelMemory"
  }
}

# Private MongoDB instance
resource "aws_instance" "database" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.database.id
  vpc_security_group_ids      = [aws_security_group.database.id]
  associate_public_ip_address = false

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name    = "TravelMemory-Database"
    Project = "TravelMemory"
  }
}

# Application Load Balancer
resource "aws_lb" "app" {
  name               = "travelmemory-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets = [
    data.aws_subnet.public_a.id,
    data.aws_subnet.public_c.id
  ]

  tags = {
    Name    = "TravelMemory-ALB"
    Project = "TravelMemory"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "travelmemory-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "TravelMemory-App-TG"
    Project = "TravelMemory"
  }
}

resource "aws_lb_target_group_attachment" "app_a" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "app_c" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app_c.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
