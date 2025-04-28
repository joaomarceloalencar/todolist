FROM python:3.13-alpine

WORKDIR /app

COPY requirements.txt requirements.txt

RUN pip install -r requirements.txt

RUN mkdir /app/todolist

RUN mkdir /app/templates

COPY wsgi.py /app/wsgi.py

COPY __init__.py /app/todolist/__init__.py

COPY base.html /app/templates/base.html

CMD [ "gunicorn", "--workers", "2",  "--bind", "0.0.0.0", "wsgi:app" ]
