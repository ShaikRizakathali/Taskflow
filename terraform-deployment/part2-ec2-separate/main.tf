terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "taskflow-tf-state-ali"
    key            = "part2-ec2-separate/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# --- NETWORKING ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-subnet-1" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# --- SECURITY GROUPS ---
# Frontend SG: Allows internet to access port 3000
resource "aws_security_group" "frontend_sg" {
  name        = "${var.project_name}-frontend-sg"
  description = "Allow SSH and Express (3000) from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Express Frontend"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-frontend-sg" }
}

# Backend SG: Allows Frontend SG to access port 5000 (AND internet for grading purposes)
resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-backend-sg"
  description = "Allow Flask (5000) from Frontend SG and internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow from Frontend SG"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    security_groups = [aws_security_group.frontend_sg.id] # <-- THE MAGIC!
  }

  ingress {
    description = "Allow from Internet (per assignment requirement)"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-backend-sg" }
}

# --- EC2 INSTANCES ---
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              apt-get update
              apt-get install -y python3 python3-pip python3-venv git
              
              git clone https://github.com/ShaikRizakathali/Taskflow.git /opt/taskflow
              cd /opt/taskflow/backend
              python3 -m venv venv
              source venv/bin/activate
              pip3 install -r requirements.txt
              
              nohup python3 app.py > /var/log/backend.log 2>&1 &
              EOF

  tags = { Name = "${var.project_name}-backend" }
}

resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  
  # Frontend needs to wait for backend to be ready, but for simplicity we just inject the IP
  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Install Node.js 18
              curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
              apt-get install -y nodejs git
              
              git clone https://github.com/ShaikRizakathali/Taskflow.git /opt/taskflow
              cd /opt/taskflow/frontend/express-frontend
              npm install
              
              # DYNAMICALLY INJECT THE BACKEND'S PRIVATE IP!
              sed -i "s|const API_URL = .*|const API_URL = 'http://${aws_instance.backend.private_ip}:5000/api/tasks';|g" public/index.html
              
              nohup npm start > /var/log/frontend.log 2>&1 &
              EOF

  tags = { Name = "${var.project_name}-frontend" }
}
