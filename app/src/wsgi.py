from todolist import create_app

# Chama a função fábrica para criar a aplicação
# Você pode passar o nome da configuração se necessário, ex: create_app('production')
app = create_app()

# O bloco if __name__ == "__main__": pode ser mantido se quiser rodar wsgi.py diretamente para testes locais
if __name__ == "__main__":
    app.run()