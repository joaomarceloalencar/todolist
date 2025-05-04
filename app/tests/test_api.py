
import pytest
from src.todolist import create_app, db # Importa a fábrica da aplicação e o objeto db
from src.todolist.models import Todo # Importa o modelo Todo

# Fixture para criar uma instância da aplicação Flask para testes
@pytest.fixture(scope='module')
def app():
    # Cria uma instância da aplicação com a configuração de teste
    # Podemos criar uma configuração de teste específica em config.py se necessário,
    # mas para este exemplo, podemos usar a de desenvolvimento ou uma simplificada.
    # Para testes de integração com o DB, precisamos de uma URL de BD válida.
    # Para testes unitários puros, poderíamos usar um DB em memória (sqlite).
    # Para testes de API que interagem com o DB, é melhor usar um DB real (ou um mock).
    # Neste caso, vamos simular o ambiente de desenvolvimento que usa o DB contêiner.
    # No ambiente Docker Compose de teste, as variáveis de ambiente serão definidas.
    # Localmente, você pode precisar defini-las antes de rodar o pytest.
    app = create_app('development') # Use a configuração de desenvolvimento ou crie uma de teste
    # Configurações específicas para testes (se necessário)
    # app.config['TESTING'] = True # Habilita o modo de teste do Flask
    # app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:' # Exemplo para DB em memória (para testes unitários)
    # Configura o contexto da aplicação para que as extensões (db, migrate) funcionem
    with app.app_context():
        # Cria as tabelas do banco de dados para os testes
        # Em testes de integração, é comum recriar o DB ou usar transações
        # para isolar cada teste. Flask-SQLAlchemy e pytest-flask podem ajudar.
        # Para este exemplo simples, vamos apenas criar as tabelas.
        # Em um cenário real com migrações, você rodaria db.create_all()
        # ou aplicaria migrações aqui.
        # db.create_all() # Pode ser usado para criar tabelas se não usar migrações nos testes
        # Limpa o banco de dados antes de cada teste (usando outra fixture)
        pass # A limpeza será feita em outra fixture
    yield app # Fornece a instância da aplicação para os testes
    # Limpeza após todos os testes do módulo (se necessário)
    # with app.app_context():
    #     db.drop_all() # Exemplo: remover tabelas
# Fixture para obter um cliente de teste Flask
@pytest.fixture
def client(app):
    # Retorna o cliente de teste da aplicação
    return app.test_client()
# Fixture para configurar o contexto da aplicação e limpar o DB antes de cada teste
@pytest.fixture(autouse=True) # autouse=True faz com que esta fixture rode automaticamente para cada teste
def setup_each_test(app):
    with app.app_context():
        # Limpa todos os dados da tabela Todo antes de cada teste
        db.session.query(Todo).delete()
        db.session.commit()
        yield # Executa o teste
        # Nenhuma limpeza adicional necessária após o teste, pois a próxima execução limpará
# Exemplo de Teste para a rota '/' (Home)
def test_home_page(client):
    # Envia uma requisição GET para a rota '/'
    response = client.get('/')
    # Verifica se o status code da resposta é 200 (OK)
    assert response.status_code == 200
    # Verifica se o conteúdo da resposta contém o título da página
    assert b"To Do App" in response.data # Use bytes para comparar com response.data
# Exemplo de Teste para a rota '/add' (POST)
def test_add_todo(client):
    # Dados do formulário para adicionar uma tarefa
    todo_data = {'title': 'Comprar Leite'}
    # Envia uma requisição POST para a rota '/add' com os dados do formulário
    response = client.post('/add', data=todo_data, follow_redirects=True) # follow_redirects segue o redirecionamento para a home
    # Verifica se o status code da resposta final (após redirecionamento) é 200 (OK)
    assert response.status_code == 200
    # Verifica se o título da nova tarefa aparece na página (após redirecionamento para a home)
    assert b"Comprar Leite" in response.data
    # Opcional: Verificar se a tarefa foi realmente adicionada ao banco de dados
    with client.application.app_context(): # Acessa o contexto da aplicação a partir do cliente
         added_todo = Todo.query.filter_by(title='Comprar Leite').first()
         assert added_todo is not None
         assert added_todo.complete is False
# Exemplo de Teste para a rota '/update/<int:todo_id>' (GET)
def test_update_todo(client):
    # Primeiro, adicione uma tarefa para poder atualizá-la
    with client.application.app_context():
        new_todo = Todo(title='Tarefa para Atualizar', complete=False)
        db.session.add(new_todo)
        db.session.commit()
        todo_id = new_todo.id # Pega o ID da tarefa recém-criada
    # Envia uma requisição GET para a rota de update, seguindo o redirecionamento
    response = client.get(f'/update/{todo_id}', follow_redirects=True)
    # Verifica o status code da resposta final
    assert response.status_code == 200
    # Verifica se o status da tarefa mudou na página (deve aparecer "Completed")
    assert b"Completed" in response.data
    # Opcional: Verificar no banco de dados
    with client.application.app_context():
        updated_todo = Todo.query.get(todo_id)
        assert updated_todo is not None
        assert updated_todo.complete is True
# Exemplo de Teste para a rota '/delete/<int:todo_id>' (GET)
def test_delete_todo(client):
    # Primeiro, adicione uma tarefa para poder deletá-la
    with client.application.app_context():
        new_todo = Todo(title='Tarefa para Deletar', complete=False)
        db.session.add(new_todo)
        db.session.commit()
        todo_id = new_todo.id # Pega o ID da tarefa recém-criada
        initial_count = Todo.query.count()
        assert initial_count == 1
    # Envia uma requisição GET para a rota de delete, seguindo o redirecionamento
    response = client.get(f'/delete/{todo_id}', follow_redirects=True)
    # Verifica o status code da resposta final
    assert response.status_code == 200
    # Verifica se o título da tarefa deletada NÃO aparece mais na página
    assert b"Tarefa para Deletar" not in response.data
    # Opcional: Verificar no banco de dados
    with client.application.app_context():
        deleted_todo = Todo.query.get(todo_id)
        assert deleted_todo is None
        assert Todo.query.count() == 0 # Verifica se a contagem voltou a zero
# Exemplo de Teste para deletar uma tarefa inexistente (deve retornar 404)
def test_delete_nonexistent_todo(client):
    # Tenta deletar um ID que não existe
    response = client.get('/delete/999', follow_redirects=True) # ID 999 provavelmente não existe
    # Verifica se a resposta final é 404 Not Found
    assert response.status_code == 404 # Assumindo que sua rota retorna 404 para IDs inexistentes (get_or_404)
# Exemplo de Teste para atualizar uma tarefa inexistente (deve retornar 404)
def test_update_nonexistent_todo(client):
    # Tenta atualizar um ID que não existe
    response = client.get('/update/999', follow_redirects=True) # ID 999 provavelmente não existe
    # Verifica se a resposta final é 404 Not Found
    assert response.status_code == 404 # Assumindo que sua rota retorna 404 para IDs inexistentes (get_or_404)
    