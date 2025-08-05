FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY server_world_class_ai.py .
COPY data/ data/

CMD ["python", "server_world_class_ai.py"]