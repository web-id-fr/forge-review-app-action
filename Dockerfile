FROM python:latest

WORKDIR /app

COPY requirements.txt .
COPY script.py .

RUN pip install --no-cache-dir -r requirements.txt

CMD ["python", "script.py"]