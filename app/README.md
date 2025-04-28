# Aplicação Exemplo

## Execução da versão de desenvolvimento

É preciso preparar o banco de dados antes da execução. Crie um ambiente virtual (Conda, pacote virtualenv, env) e instale as dependências:

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
docker-compose -f docker-compose-dev.yml down db
```

Suba a aplicação:
```
docker-compose -f docker-compose-dev.yml down --volumes --remove-orphans # Caso tenha algum resquício de execução anterior.
docker-compose -f docker-compose-dev.yml up --build
```