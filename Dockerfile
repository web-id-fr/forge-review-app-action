FROM python:latest

WORKDIR /app

COPY requirements.txt .

COPY scripts/script.py .

RUN pip install --no-cache-dir -r requirements.txt

ENTRYPOINT ["python", "scripts/script.py"]