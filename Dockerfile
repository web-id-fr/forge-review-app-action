FROM python:latest

WORKDIR /app

COPY requirements.txt /requirements.txt
COPY script.py /script.py

RUN pip install --no-cache-dir -r requirements.txt

ENTRYPOINT ["python", "/script.py"]