variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.xlarge" # 4 vCPU, 16GB RAM - meets the assignment minimum
}

variable "root_volume_size_gb" {
  type    = number
  default = 50
}

variable "key_name" {
  type        = string
  description = "Existing AWS key pair name to use for SSH access"
}

variable "environment" {
  type    = string
  default = "dev"
}
