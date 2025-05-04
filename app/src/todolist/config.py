import os

class Config:
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'uma-chave-secreta-dificil-de-adivinhar' # Ler de variável de ambiente

class DevelopmentConfig(Config):
    DEBUG = True
    SQLALCHEMY_DATABASE_URI = os.environ.get('DEV_DATABASE_URL') or \
                              'postgresql://todolist:todolist@db/todolist' # URL para dev

class HomologationConfig(Config):
    # DEBUG = False
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') # Ler de variável de ambiente (AWS RDS)
    # Configurações de logging, etc.

class ProductionConfig(Config):
    # DEBUG = False
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') # Ler de variável de ambiente (AWS RDS)
    # Configurações de logging, etc.

config_by_name = {
    'development': DevelopmentConfig,
    'homologation': HomologationConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}