# Aplicação Exemplo

Considerando o ambiente como Ubuntu 24.04

## Execução da versão de desenvolvimento

Configure as variáveis de ambiente:

```
# Definir as variáveis de ambiente para o comando flask (ou copie env-dev para .env)
export FLASK_APP=src/wsgi.py
export FLASK_ENV=development 
export DEV_DATABASE_URL='postgresql://todolist:todolist@localhost:5432/todolist'
export SECRET_KEY='sua_chave_secreta_para_desenvolvimento' # Defina uma chave para uso local
export PYTHONPATH=./src # Adicione o caminho para a pasta src localmente
```

Suba a aplicação:
```
sudo docker compose -f docker-compose-dev.yml up --build
```

O sudo é necessário pois o PostGreSQL cria a pasta _instance_ para armazenar seus arquivos como superusuário.

## Reinicialização do Banco.

Caso por alguma razão deseje reiniciar o banco de dados, siga os passos abaixo:.

Remova a pasta migrations:

```
rm -r migrations
```

Crie um ambiente virtual (Conda, pacote virtualenv, env) e instale as dependências:

```
python3 -m venv todolist
source todolist/bin/activate 
pip install -r requirements.txt
```

Execute apenas o banco de dados:
```
docker-compose -f docker-compose-dev.yml up -d db
docker-compose -f docker-compose-dev.yml ps
```

Configure as variáveis de ambiente:

```
# Definir as variáveis de ambiente para o comando flask (ou copie env-dev para .env)
export FLASK_APP=src/wsgi.py
export FLASK_ENV=development 
export DEV_DATABASE_URL='postgresql://todolist:todolist@localhost:5432/todolist'
export SECRET_KEY='sua_chave_secreta_para_desenvolvimento' # Defina uma chave para uso local
export PYTHONPATH=./src # Adicione o caminho para a pasta src localmente
```

Faça a migração do banco de dados:
```
flask db init
flask db migrate -m "Initial migration"
docker compose -f docker-compose-dev.yml down db
```

Depois é só subir a aplicação.