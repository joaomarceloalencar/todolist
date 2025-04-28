from flask import Blueprint, render_template, request, redirect, url_for
from . import db # Importa o objeto db e outras coisas de __init__.py
from .models import Todo # Importa o modelo Todo (se movido para models.py)

# Cria um Blueprint. O primeiro argumento é o nome do blueprint (ex: 'main').
# url_prefix pode ser usado se todas as rotas deste blueprint tiverem um prefixo comum.
bp = Blueprint('main', __name__)

@bp.route('/')
def home():
    todo_list = Todo.query.all()
    return render_template("base.html", todo_list=todo_list) # template_folder é configurado na factory ou blueprint

@bp.route("/add", methods=["POST"])
# Dentro da função add() no routes.py (se usar blueprints)

@bp.route("/add", methods=["POST"])
def add():
    title = request.form.get("title")
    # Validação simples
    if not title or len(title.strip()) == 0:
         # Adicionar feedback para o usuário - necessita de Flask-Flash e ajustar o template
         # flash('O título da tarefa não pode estar vazio!', 'warning')
         return redirect(url_for("main.home")) # Redireciona de volta para a página inicial

    new_todo = Todo(title=title.strip(), complete=False) # Salvar sem espaços em branco extras
    db.session.add(new_todo)
    db.session.commit()
    return redirect(url_for("main.home"))

# Dentro da função update() no routes.py

@bp.route("/update/<int:todo_id>")
def update(todo_id):
    # Busca o item e retorna 404 se não encontrar
    todo = Todo.query.get_or_404(todo_id)
    todo.complete = not todo.complete
    db.session.commit()
    return redirect(url_for("main.home"))

# Dentro da função delete() no routes.py

@bp.route("/delete/<int:todo_id>")
def delete(todo_id):
    # Busca o item e retorna 404 se não encontrar
    todo = Todo.query.get_or_404(todo_id)
    db.session.delete(todo)
    db.session.commit()
    return redirect(url_for("main.home"))