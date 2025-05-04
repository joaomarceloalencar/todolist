# Define o provedor AWS e a região
provider "aws" {
  region = "us-east-1"
}

# Configuração dos providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source para obter a AMI mais recente do Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

# Data source para verificar se a chave já existe
data "aws_key_pair" "existing_key" {
  key_name = "deployer-key-hml"
  count = try(data.aws_key_pair.existing_key[0].key_name, "") != "" ? 1 : 0
}

# Cria um par de chaves SSH apenas se não existir
resource "aws_key_pair" "deployer_key" {
  count = try(data.aws_key_pair.existing_key[0].key_name, "") != "" ? 0 : 1
  
  key_name = "deployer-key-hml"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCnCIqCj662njuTA/DSftx9xBRRSxv7yeg1hlTwRDBZF40x87dT5ZNCNYsYEtAAwDXeuFKC7V5nLhfEV/Chde+RTxEbOJQVd6HKLebrxW+9WldoeWrCzwDugP5N+ViwDpHE1CORiqupVuvn5q3G4Ygt3kKLrEg7tEwrB/GDk5jF8O9H2fGA3VqpRKrmn9WjUE8Q3jExA0ktzA0BaQL+UoicxeU55Dkddsk9KS9adYjh9Z6cElumpW8/W2fEr1oJDfKf0DR4pmWLAFl9w8/qQuWeMnOf+dMlrn7Dg97yk75Rg/yNBK5l4/18WqwCTCITLsHiR48/LDI1HX1Qpn76yERyhmGczreQ0h4lLeQsSWrJrJC6jV+xUwKpjGk1mZs6zVSP3yyD6Fuc76ur1a+dNgUG2wwNJ2s1RP0thW4a3roqWT4j+5Fcl9S18COGGjtI5MxWeOxgXop7LYNu+cqqClrXbPUYWyHV194PzGttLtiN1atwFjieDx2+aU9uOqoONiGYArXyl/9h+L0rOTdPT9/I6+4sW1V0J5XuKqgXsu9vuGNAFhioyJZuHud6r093lqtKW4O20xnp1sQ8FZkeU8YDBdHT3e+4FnqBQu5eorDRA4TIByvXZfsydaNphtLWe/LEO8nrhr7dDPLbNwVt70ZxdybxJNq4QRuPg5/F0Wj3LQ== joao.marcelo@ufc.br"
}

# Data source para verificar se o security group já existe
data "aws_security_group" "existing_sg" {
  name = "hml-security-group"
  count = try(data.aws_security_group.existing_sg[0].id, "") != "" ? 1 : 0
}

# Cria um Security Group apenas se não existir
resource "aws_security_group" "hml_sg" {
  count = try(data.aws_security_group.existing_sg[0].id, "") != "" ? 0 : 1

  name        = "hml-security-group"
  description = "Allow SSH and HTTP traffic to HML instance"

  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP from anywhere"
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
    Name = "hml-security-group"
  }
}

# Data source para verificar se a instância já existe
data "aws_instances" "existing_instance" {
  filter {
    name   = "tag:Name"
    values = ["todolist-hml-instance"]
  }
  
  filter {
    name   = "instance-state-name"
    values = ["running", "stopped"]
  }
}

# Local para armazenar se a instância existe
locals {
  instance_exists = length(data.aws_instances.existing_instance.ids) > 0
}

# Cria a instância EC2 apenas se não existir
resource "aws_instance" "hml_instance" {
  count = local.instance_exists ? 0 : 1

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  
  key_name = try(data.aws_key_pair.existing_key[0].key_name, aws_key_pair.deployer_key[0].key_name)
  
  vpc_security_group_ids = [
    try(data.aws_security_group.existing_sg[0].id, aws_security_group.hml_sg[0].id)
  ]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name        = "todolist-hml-instance"
    Project     = "todolist-devops-course"
    Environment = "homologation"
  }
}

# Outputs adaptados para lidar com instância existente ou nova
output "hml_instance_public_ip" {
  description = "Public IP address of the HML EC2 instance"
  value = local.instance_exists ? data.aws_instances.existing_instance.public_ips[0] : (
    length(aws_instance.hml_instance) > 0 ? aws_instance.hml_instance[0].public_ip : null
  )
}

output "hml_key_pair_name" {
  description = "Name of the SSH key pair for HML instance"
  value = try(data.aws_key_pair.existing_key[0].key_name, aws_key_pair.deployer_key[0].key_name)
}

output "hml_security_group_id" {
  description = "ID of the Security Group used for HML instance"
  value = try(data.aws_security_group.existing_sg[0].id, aws_security_group.hml_sg[0].id)
}

# Output adicional para mostrar se está usando instância existente
output "using_existing_instance" {
  description = "Indicates if we're using an existing instance"
  value = local.instance_exists
}