import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate

# Importa a configuração
from .config import config_by_name

# Inicializa a extensão SQLAlchemy.
# Não passamos a instância 'app' aqui, pois será inicializada na fábrica.
db = SQLAlchemy()
# Se usar Flask-Migrate, inicialize-o aqui também:
migrate = Migrate()

def create_app(config_name=None):
    """
    Cria a instância da aplicação Flask usando o padrão Application Factory.

    Args:
        config_name (str, optional): O nome da configuração a ser usada
                                     ('development', 'homologation', 'production').
                                     Se None, tenta ler da variável de ambiente FLASK_ENV.
                                     Padrão: 'default' (development).
    """
    app = Flask(__name__,
                instance_relative_config=True,
                template_folder='../../templates') 
    
    # Determina qual configuração carregar
    if config_name is None:
        config_name = os.environ.get('FLASK_ENV', 'default')

    # Carrega a configuração a partir do objeto de configuração
    app.config.from_object(config_by_name.get(config_name, config_by_name['default']))

    # Tenta carregar configuração de um arquivo config.py na pasta 'instance'
    # (útil para configurações locais que não vão para o Git)
    # app.config.from_pyfile('config.py', silent=True)

    # --- DEBUG: Imprimir a URL do BD que está sendo usada ---
    print(f"DEBUG: FLASK_ENV usado: {config_name}")
    print(f"DEBUG: SQLALCHEMY_DATABASE_URI configurado: {app.config.get('SQLALCHEMY_DATABASE_URI')}")
    # --- FIM DEBUG ---

    # Inicializa as extensões com a instância 'app' criada
    db.init_app(app)
    migrate.init_app(app, db)

    # Importa e registra Blueprints.
    # Assume que você tem um arquivo routes.py com um Blueprint chamado 'bp'.
    from . import routes
    app.register_blueprint(routes.bp)

    # Opcional: Adicionar comandos de shell personalizados (ex: 'flask create-db')
    # from .commands import custom_cli_commands # Assumindo que você crie commands.py
    # app.cli.add_command(custom_cli_commands)


    # O trecho db.create_all() e o try/except foram removidos daqui.
    # A criação/atualização do esquema do banco de dados deve ser feita idealmente
    # via scripts de migração (Alembic/Flask-Migrate) executados no pipeline CI/CD
    # ou manualmente no ambiente de desenvolvimento. Para o exemplo do curso,
    # você pode demonstrar rodar 'flask db upgrade' ou um script de setup inicial.


    return app

# Este bloco __main__ é geralmente usado para rodar a aplicação localmente
# durante o desenvolvimento. Em produção (com Gunicorn, por exemplo),
# o create_app() será chamado pelo arquivo wsgi.py.
# if __name__ == "__main__":
#     app = create_app()
#     app.run(debug=True) # Usar debug=True SOMENTE em desenvolvimento