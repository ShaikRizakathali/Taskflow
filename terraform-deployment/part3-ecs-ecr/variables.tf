variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "taskflow-part3"
}

variable "container_port_frontend" {
  description = "Frontend container port"
  type        = number
  default     = 3000
}

variable "container_port_backend" {
  description = "Backend container port"
  type        = number
  default     = 5000
}
