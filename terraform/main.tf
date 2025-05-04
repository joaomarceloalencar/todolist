# Define o provedor AWS e a região
provider "aws" {
  region = "us-east-1" # Defina a região da AWS que você está usando (ajuste conforme sua AWS Academy)
}

# Data source para obter a AMI mais recente do Ubuntu 24.04 LTS
# Isso garante que você sempre use a versão mais recente do sistema operacional
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"] # Padrão de nome para Ubuntu 24.04 LTS
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # ID do proprietário oficial das AMIs do Ubuntu (Canonical)
}

# Cria um par de chaves SSH para acesso à instância EC2
# A chave privada correspondente DEVE ser armazenada como um GitHub Secret
resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key-hml" # Nome da chave na AWS
  # A chave pública correspondente à chave privada armazenada no GitHub Secret
  # Você precisará gerar um par de chaves SSH localmente e colar a chave pública aqui.
  # Exemplo: ssh-keygen -t rsa -b 4096 -C "seu_email@example.com"
  # Cole o conteúdo do arquivo .pub gerado aqui (ex: ~/.ssh/deployer-key-hml.pub)
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCnCIqCj662njuTA/DSftx9xBRRSxv7yeg1hlTwRDBZF40x87dT5ZNCNYsYEtAAwDXeuFKC7V5nLhfEV/Chde+RTxEbOJQVd6HKLebrxW+9WldoeWrCzwDugP5N+ViwDpHE1CORiqupVuvn5q3G4Ygt3kKLrEg7tEwrB/GDk5jF8O9H2fGA3VqpRKrmn9WjUE8Q3jExA0ktzA0BaQL+UoicxeU55Dkddsk9KS9adYjh9Z6cElumpW8/W2fEr1oJDfKf0DR4pmWLAFl9w8/qQuWeMnOf+dMlrn7Dg97yk75Rg/yNBK5l4/18WqwCTCITLsHiR48/LDI1HX1Qpn76yERyhmGczreQ0h4lLeQsSWrJrJC6jV+xUwKpjGk1mZs6zVSP3yyD6Fuc76ur1a+dNgUG2wwNJ2s1RP0thW4a3roqWT4j+5Fcl9S18COGGjtI5MxWeOxgXop7LYNu+cqqClrXbPUYWyHV194PzGttLtiN1atwFjieDx2+aU9uOqoONiGYArXyl/9h+L0rOTdPT9/I6+4sW1V0J5XuKqgXsu9vuGNAFhioyJZuHud6r093lqtKW4O20xnp1sQ8FZkeU8YDBdHT3e+4FnqBQu5eorDRA4TIByvXZfsydaNphtLWe/LEO8nrhr7dDPLbNwVt70ZxdybxJNq4QRuPg5/F0Wj3LQ== joao.marcelo@ufc.br"
}

# Cria um Security Group para a instância EC2
# Permite tráfego SSH (porta 22) do seu IP (ou de qualquer lugar para simplificar no curso)
# Permite tráfego HTTP (porta 80) de qualquer lugar para acessar a aplicação
resource "aws_security_group" "hml_sg" {
  name        = "hml-security-group"
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
    Name = "hml-security-group"
  }
}

# Cria a instância EC2
resource "aws_instance" "hml_instance" {
  ami           = data.aws_ami.ubuntu.id # Usa a AMI do Ubuntu 24.04 encontrada
  instance_type = "t3.medium" # Tipo de instância conforme o plano
  key_name      = aws_key_pair.deployer_key.key_name # Associa o par de chaves criado
  # subnet_id = "subnet-xxxxxxxxxxxxxxxxx" # Opcional: Especifique uma subnet se não usar a default
  security_groups = [aws_security_group.hml_sg.name] # Associa o Security Group criado

  # User data para executar comandos na inicialização (opcional, mas útil para setup inicial)
  # user_data = <<-EOF
  # #!/bin/bash
  # echo "Hello from user data!" >> /tmp/user_data.log
  # # Você pode adicionar comandos aqui para instalar coisas básicas ou configurar o ambiente
  # EOF

  tags = {
    Name    = "todolist-hml-instance" # Nome da instância
    Project = "todolist-devops-course"
    Environment = "homologation"
  }
}

# Define a saída do IP público da instância EC2
# Este valor será usado pelo Ansible para se conectar
output "hml_instance_public_ip" {
  description = "Public IP address of the HML EC2 instance"
  value       = aws_instance.hml_instance.public_ip
}

# Define a saída do nome da chave SSH
output "hml_key_pair_name" {
  description = "Name of the SSH key pair for HML instance"
  value       = aws_key_pair.deployer_key.key_name
}
