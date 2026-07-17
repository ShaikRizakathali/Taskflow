terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Configure the S3 backend for state management
  backend "s3" {
    bucket         = "taskflow-tf-state-ali"
    key            = "part1-ec2-single/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# Fetch the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security Group for the EC2 instance
resource "aws_security_group" "taskflow_sg" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH, Express (3000), and Flask (5000)"

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

  ingress {
    description = "Flask Backend"
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

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# EC2 Instance
resource "aws_instance" "taskflow_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.taskflow_sg.id]

  # User data script to bootstrap the server
  user_data = <<-EOF
              #!/bin/bash
              set -e # Exit on any error

              # Update and install dependencies
              apt-get update
              apt-get install -y python3 python3-pip python3-venv nodejs npm git

              # Clone the repository
              git clone https://github.com/ShaikRizakathali/Taskflow.git /opt/taskflow
              cd /opt/taskflow

              # --- Setup Backend ---
              cd /opt/taskflow/backend
              python3 -m venv venv
              source venv/bin/activate
              pip3 install -r requirements.txt
              # Start backend in background
              nohup python3 app.py > /var/log/backend.log 2>&1 &

              # --- Setup Frontend ---
              cd /opt/taskflow/frontend/express-frontend
              npm install
              
              # CRITICAL: Update the frontend to point to the local backend on port 5000
              sed -i "s|const API_URL = .*|const API_URL = 'http://localhost:5000/api/tasks';|g" public/index.html
              
              # Start frontend in background
              nohup npm start > /var/log/frontend.log 2>&1 &
              EOF

  tags = {
    Name = "${var.project_name}-instance"
  }
}
