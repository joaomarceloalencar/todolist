# Define o provedor AWS e a região
provider "aws" {
  region = "us-east-1" # Defina a região da AWS que você está usando (ajuste conforme sua AWS Academy)
}

# Configura o backend S3 para armazenar o estado do Terraform
terraform {
  backend "s3" {
    # bucket = "joao-marcelo-terraform-state-todolist" # <--- Precisa ser criado antes com "aws s3api create-bucket --bucket SEUNOME-terraform-state-todolist --region us-east-1"
    key    = "terraform.tfstate"             # Caminho dentro do bucket para o arquivo de estado
    region = "us-east-1"                         # <--- Defina a região do seu bucket S3
    # Configuração para bloqueio de estado com DynamoDB (recomendado)
    dynamodb_table = "terraform-state-locking-todolist" # <--- Precisa ser criada antes com "aws dynamodb create-table --table-name terraform-state-locking-todolist --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST"
    # 
    encrypt        = true                        # Criptografa o estado no S3
  }
}

# Nova variável para definir o ambiente de deploy
variable "environment" {
  description = "Ambiente de deploy (ex: 'homologation', 'production')."
  type        = string
  # Pode definir um valor padrão se necessário, mas é melhor forçar a definição
}

variable "public_key" {
  description = "Chave pública a ser instalada na instância.."
  type        = string
}

# Data source para obter a AMI mais recente do Ubuntu 24.04 LTS
# Isso garante que você sempre use a versão mais recente do sistema operacional
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"] # Padrão de nome para Ubuntu 24.04 LTS (ajustado conforme sua descoberta)
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # ID do proprietário oficial das AMIs do Ubuntu (Canonical)
}

# Cria um par de chaves SSH para acesso à instância EC2
# Este recurso será criado em cada execução se não existir
resource "aws_key_pair" "deployer_key" {
  key_name = "${var.environment}-deployer-key"  # Nome da chave na AWS
  # A chave pública correspondente à chave privada armazenada no GitHub Secret
  # Você precisará gerar um par de chaves SSH localmente e colar a chave pública aqui.
  # Exemplo: ssh-keygen -t rsa -b 4096 -C "seu_email@example.com"
  # Cole o conteúdo COMPLETO do arquivo .pub gerado aqui (ex: ~/.ssh/deployer-key-hml.pub)
  # Certifique-se de que NÃO há espaços em branco extras ou quebras de linha.
  public_key = "${var.public_key}" # Substitua pelo conteúdo da chave pública
}

# Cria um Security Group para a instância EC2
# Este recurso será criado em cada execução se não existir
resource "aws_security_group" "app_sg" {
  name        = "${var.environment}-app-security-group" 
  description = "Allow SSH and HTTP traffic to HML instance"
  # vpc_id = "vpc-xxxxxxxxxxxxxxxxx" # Opcional: Especifique uma VPC se não usar a default

  # Regra de entrada para SSH (porta 22)
  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # cidr_blocks = ["SEU_IP_PUBLICO/32"] # Melhor prática: restringir SSH ao seu IP
    cidr_blocks = ["0.0.0.0/0"] # Para simplificar no curso, permite de qualquer lugar (menos seguro)
  }

  # Regra de entrada para HTTP (porta 80)
  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Permite acesso HTTP de qualquer lugar
  }

  # Regra de saída (permite todo o tráfego de saída)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-app-security-group" # Tag Name dinâmica
  }
}

# Cria a instância EC2
resource "aws_instance" "app_instance" {
  ami           = data.aws_ami.ubuntu.id # Usa a AMI do Ubuntu 24.04 encontrada
  instance_type = var.environment == "production" ? "t3.large" : "t3.medium" # Define o tipo de instância conforme o plano
  key_name      = aws_key_pair.deployer_key.key_name # Associa o par de chaves criado
  vpc_security_group_ids = [aws_security_group.app_sg.id] # Referencia o ID do Security Group criado

  # subnet_id = "subnet-xxxxxxxxxxxxxxxxx" # Opcional: Especifique uma subnet se não usar a default

  # User data para executar comandos na inicialização (opcional, mas útil para setup inicial)
  # user_data = <<-EOF
  # #!/bin/bash
  # echo "Hello from user data!" >> /tmp/user_data.log
  # # Você pode adicionar comandos aqui para instalar coisas básicas ou configurar o ambiente
  # EOF

  tags = {
     Name    = "todolist-${var.environment}-instance" # Nome da instância
    Project = "todolist-devops-course"
    Environment = "homologation"
  }
}

# Define a saída do IP público da instância EC2
# Este valor será usado pelo Ansible para se conectar
output "app_instance_public_ip" {
  description = "Public IP address of the HML EC2 instance"
  value       = aws_instance.app_instance.public_ip
}

# Define a saída do nome da chave SSH
output "deployer_key_name" {
  description = "Name of the SSH key pair for HML instance"
  value       = aws_key_pair.deployer_key.key_name
}

# Define a saída do ID do Security Group usado
output "app_security_group_id" {
  description = "ID of the Security Group used for HML instance"
  value = aws_security_group.app_sg.id
}

# REMOVIDOS: Outputs de Debug Temporários
