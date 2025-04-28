FROM python:3.13-alpine

WORKDIR /app

COPY requirements.txt requirements.txt

RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

ENV FLASK_APP=wsgi.py

EXPOSE 8000

CMD ["gunicorn", "-b", "0.0.0.0:8000", "wsgi:app", "--workers", "4", "--threads", "2", "--timeout", "120"]
