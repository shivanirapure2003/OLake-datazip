terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Default backend: local state (assignment accepts local state). 
  # To use S3 remote state, replace this backend block with an S3 backend and provide bucket/key.
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "olake_sg" {
  name        = "olake-sg-${var.environment}"
  description = "Security group for OLake VM"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OLake UI"
    from_port   = 8000
    to_port     = 8000
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
    Name        = "olake-sg-${var.environment}"
    Environment = var.environment
    Project     = "OLake-Assignment"
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_subnet" "default_subnet" {
  availability_zone = data.aws_availability_zones.available.names[0]
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = cidrsubnet(data.aws_vpc.default.cidr_block, 8, 0)
  tags = {
    Name = "olake-subnet-${var.environment}"
  }
}

data "aws_availability_zones" "available" {}

data "aws_key_pair" "user_key" {
  key_name = var.key_name
}

resource "aws_instance" "olake_vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  associate_public_ip_address = true
  subnet_id              = data.aws_subnet.default_subnet.id
  vpc_security_group_ids = [aws_security_group.olake_sg.id]

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
  }

  tags = {
    Name        = "olake-vm-${var.environment}"
    Environment = var.environment
    Project     = "OLake-Assignment"
  }

  provisioner "file" {
    source      = "${path.module}/../values.yaml"
    destination = "/home/ubuntu/values.yaml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.public_ip
      agent       = true
    }
  }

  provisioner "file" {
    source      = "${path.module}/../minikube-setup.sh"
    destination = "/home/ubuntu/minikube-setup.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.public_ip
      agent       = true
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/minikube-setup.sh",
      "sudo /home/ubuntu/minikube-setup.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.public_ip
      agent       = true
    }
  }
}

resource "aws_eip" "olake_eip" {
  instance = aws_instance.olake_vm.id
  vpc      = true
  tags = {
    Name = "olake-eip-${var.environment}"
  }
}

output "vm_public_ip" {
  description = "Public IP of the OLake VM"
  value       = aws_eip.olake_eip.public_ip
}

output "instance_id" {
  description = "EC2 instance id"
  value       = aws_instance.olake_vm.id
}

output "ssh_connection" {
  value = "ssh -A -i <your-private-key> ubuntu@${aws_eip.olake_eip.public_ip}"
}
