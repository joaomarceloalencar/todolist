# terraform/prod.tf
# Define os recursos específicos do ambiente de produção (RDS PostgreSQL)
# Estes recursos SÓ serão criados se a variável 'environment' for "production"

# Data source para obter a VPC padrão (se não estiver usando uma VPC customizada)
# Precisamos do ID da VPC para criar o Security Group e o Subnet Group
data "aws_vpc" "default" {
  default = true
}

# Data source para obter as subnets da VPC padrão
# Precisamos dos IDs das subnets para criar o DB Subnet Group
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Cria um DB Subnet Group
# É necessário para o RDS saber em quais subnets implantar instâncias
# Este recurso SÓ será criado se a variável 'environment' for "production"
resource "aws_db_subnet_group" "prod_rds_subnet_group" {
  count = var.environment == "production" ? 1 : 0 # Criação condicional: 1 se production, 0 caso contrário

  name       = "prod-rds-subnet-group"
  subnet_ids = data.aws_subnets.default.ids # Usa os IDs das subnets da VPC padrão
  tags = {
    Name = "prod-rds-subnet-group"
  }
}

# Cria um Security Group para o RDS
# Permite tráfego PostgreSQL (porta 5432) APENAS da instância EC2
# Este recurso SÓ será criado se a variável 'environment' for "production"
resource "aws_security_group" "prod_rds_sg" {
  count = var.environment == "production" ? 1 : 0 # Criação condicional: 1 se production, 0 caso contrário

  name        = "prod-rds-security-group"
  description = "Allow PostgreSQL traffic from EC2 instance to RDS"
  vpc_id      = data.aws_vpc.default.id # Associa ao ID da VPC padrão

  # Regra de entrada para PostgreSQL (porta 5432)
  ingress {
    description = "Allow PostgreSQL from EC2 instance"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # Permite tráfego APENAS do Security Group associado à instância EC2
    # Referencia o ID do Security Group da instância EC2 (assumindo que ele é criado incondicionalmente em main.tf)
    security_groups = [aws_security_group.app_sg.id]
  }

  # Regra de saída (permite todo o tráfego de saída)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prod-rds-security-group"
  }
}

# Cria a instância RDS PostgreSQL
# Este recurso SÓ será criado se a variável 'environment' for "production"
resource "aws_db_instance" "prod_db_instance" {
  count = var.environment == "production" ? 1 : 0 # Criação condicional: 1 se production, 0 caso contrário

  allocated_storage    = 20                                # Tamanho do armazenamento em GB (mínimo para free tier ou básico)
  storage_type         = "gp2"                             # Tipo de armazenamento (gp2 para propósito geral)
  engine               = "postgres"                        # Motor do banco de dados
  engine_version       = "17.4"                            # Versão do motor (verifique versões disponíveis na AWS)
  instance_class       = "db.t3.micro"                     # Classe da instância (verifique opções, t3.micro geralmente é a mais barata)
  db_name              = "todolistprod"                 # Nome do banco de dados
  username             = var.rds_username_prod             # Lendo da variável de entrada (segredo)
  password             = var.rds_password_prod             # Lendo da variável de entrada (segredo)
  db_subnet_group_name = aws_db_subnet_group.prod_rds_subnet_group[0].name # Associa ao Subnet Group criado (acesso com [0] pois é contado)
  vpc_security_group_ids = [aws_security_group.prod_rds_sg[0].id] # Associa ao Security Group criado para o RDS (acesso com [0] pois é contado)
  skip_final_snapshot  = true                              # NÃO recomendado para produção real, mas útil para testes para destruir mais rápido
  publicly_accessible  = false                             # NÃO torne o BD acessível publicamente em produção!

  tags = {
    Name    = "todolist-prod-db"
    Project = "todolist-devops-course"
    Environment = "production"
  }
}

# --- Variáveis de Entrada para Credenciais do RDS ---

variable "rds_username_prod" {
  description = "Nome de usuário para a instância RDS de produção."
  type        = string
  sensitive   = true # Marca como sensível para mascarar em logs
}

variable "rds_password_prod" {
  description = "Senha para a instância RDS de produção."
  type        = string
  sensitive   = true # Marca como sensível para mascarar em logs
}

# --- Fim Variáveis de Entrada para Credenciais do RDS ---


# --- Saídas (Outputs) para Detalhes de Conexão do RDS ---

# Estes outputs SÓ terão valores se a instância RDS for criada (count > 0)
output "rds_endpoint_prod" {
  description = "Endpoint da instância RDS de produção."
  value       = length(aws_db_instance.prod_db_instance) > 0 ? aws_db_instance.prod_db_instance[0].address : "" # Acessa com [0] e condicional
}

output "rds_port_prod" {
  description = "Porta da instância RDS de produção."
  value       = length(aws_db_instance.prod_db_instance) > 0 ? aws_db_instance.prod_db_instance[0].port : "" # Acessa com [0] e condicional
}

output "rds_db_name_prod" {
  description = "Nome do banco de dados na instância RDS de produção."
  value       = length(aws_db_instance.prod_db_instance) > 0 ? aws_db_instance.prod_db_instance[0].db_name : "" # Acessa com [0] e condicional
}

# NÃO exponha a senha em outputs em produção real!
# Para o curso, pode ser útil para debug, mas remova em produção.
output "rds_username_prod_output" {
  description = "Nome de usuário da instância RDS de produção (para debug)."
  value       = length(aws_db_instance.prod_db_instance) > 0 ? aws_db_instance.prod_db_instance[0].username : "" # Acessa com [0] e condicional
  sensitive   = true # Marca como sensível
}

output "rds_password_prod_output" {
  description = "Senha da instância RDS de produção (para debug)."
  value       = length(aws_db_instance.prod_db_instance) > 0 ? aws_db_instance.prod_db_instance[0].password : "" # Acessa com [0] e condicional
  sensitive   = true # Marca como sensível
}
