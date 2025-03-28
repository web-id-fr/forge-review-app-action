# Utilisation de la dernière version de Python
FROM python:latest

# Définition du répertoire de travail
WORKDIR /app

# Copie des fichiers nécessaires
COPY requirements.txt .
COPY script.py .

# Installation des dépendances
RUN pip install --no-cache-dir -r requirements.txt

# Définition du point d'entrée de l'action
ENTRYPOINT ["python", "script.py"]
