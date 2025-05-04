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
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"] # Padrão de nome para Ubuntu 24.04 LTS (ajustado conforme sua descoberta)
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # ID do proprietário oficial das AMIs do Ubuntu (Canonical)
}

# --- Lógica para encontrar ou criar o par de chaves SSH ---

# Tenta encontrar um par de chaves SSH existente pelo nome
data "aws_key_pair" "existing_deployer_key" {
  key_name = "deployer-key-hml" # Nome da chave que esperamos encontrar
}

# Cria um par de chaves SSH para acesso à instância EC2
# Este recurso SÓ será criado se o data source acima NÃO encontrar uma chave existente.
resource "aws_key_pair" "deployer_key" {
  # Usa 'count' para criar este recurso apenas se o data source falhar ao encontrar a chave.
  # A função 'can' verifica se a expressão pode ser avaliada sem erro.
  # Se o data source falhar (chave não encontrada), can() retornará false, e count será 1.
  # Se o data source for bem-sucedido (chave encontrada), can() retornará true, e count será 0.
  count = can(data.aws_key_pair.existing_deployer_key.id) ? 0 : 1

  key_name = "deployer-key-hml" # Nome da chave na AWS
  # A chave pública correspondente à chave privada armazenada no GitHub Secret
  # Você precisará gerar um par de chaves SSH localmente e colar a chave pública aqui.
  # Exemplo: ssh-keygen -t rsa -b 4096 -C "seu_email@example.com"
  # Cole o conteúdo do arquivo .pub gerado aqui (ex: ~/.ssh/deployer-key-hml.pub)
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1z8eE3OldFY2xpk5/UwJ8FyfemhFsKEg7KVsVzaynOB0D2kzRVZd6OC0iJiAHvMvo8Yxvs6dcMUJE5hiMrfd0uQGm51XeKOa/ORGI7GVrNGYKagcKsS5Mqyhvs8ljUAq7XzR53eNs1mXWbDrpG3LrFBS/6QHkFKYzXKfAP7RDjdwOE23Phv065Ki4Tg0f/yF6QUFYALAGgwRRR1c1sT3rt9RNo2BHRRz879HaVGGSOmBNxrmi7AG/av6I7vkxCoXhwm9vk6zTf+N+JWI+D7i8DeCKXUxJHS71VzDTiprXvsXKp1NMjarWtdqVSd4lHDAjhr/AT+2DnEQtEhmIhgf9ED5jEBWn5w+UF4hFkIJTVrjVuMbsOhvw8SXQ9EdSNN97kYvd22cW7wGUfXKivMQ7ztxrb04K" # <--- Cole sua chave pública aqui
}

# --- Fim Lógica para encontrar ou criar o par de chaves SSH ---


# --- Lógica para encontrar ou criar o Security Group ---

# Tenta encontrar um Security Group existente pelo nome
data "aws_security_group" "existing_hml_sg" {
  name = "hml-security-group" # Nome do Security Group que esperamos encontrar
}

# Cria um Security Group para a instância EC2
# Este recurso SÓ será criado se o data source acima NÃO encontrar um Security Group existente.
resource "aws_security_group" "hml_sg" {
  # Usa 'count' para criar este recurso apenas se o data source falhar ao encontrar o SG.
  # Se o data source falhar (SG não encontrado), can() retornará false, e count será 1.
  # Se o data source for bem-sucedido (SG encontrado), can() retornará true, e count será 0.
  count = can(data.aws_security_group.existing_hml_sg.id) ? 0 : 1 # <=== Lógica condicional

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

# --- Fim Lógica para encontrar ou criar o Security Group ---


# Cria a instância EC2
resource "aws_instance" "hml_instance" {
  ami           = data.aws_ami.ubuntu.id # Usa a AMI do Ubuntu 24.04 encontrada
  instance_type = "t3.medium" # Tipo de instância conforme o plano
  # Associa o par de chaves. Usa o nome fixo já que a lógica acima garante que ele existe.
  key_name      = "deployer-key-hml"

  # Associa o Security Group. Usa o ID do SG encontrado pelo data source OU o ID do SG criado pelo resource.
  # Usando a contagem do recurso para decidir qual ID usar.
  security_groups = [aws_security_group.hml_sg.count > 0 ? aws_security_group.hml_sg[0].id : data.aws_security_group.existing_hml_sg.id] # <=== CORRIGIDO: Referência usando count

  # subnet_id = "subnet-xxxxxxxxxxxxxxxxx" # Opcional: Especifique uma subnet se não usar a default

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
  # Usa o nome fixo já que a lógica acima garante que ele existe.
  value       = "deployer-key-hml"
}

# Define a saída do ID do Security Group usado
output "hml_security_group_id" {
  description = "ID of the Security Group used for HML instance"
  # Usa o ID do SG encontrado pelo data source OU o ID do SG criado pelo resource.
  # Usando a contagem do recurso para decidir qual ID usar.
  value = aws_security_group.hml_sg.count > 0 ? aws_security_group.hml_sg[0].id : data.aws_security_group.existing_hml_sg.id # <=== CORRIGIDO: Referência usando count
}
