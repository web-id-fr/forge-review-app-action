# Utilisation de la dernière version de Python
FROM python:latest

# Définition du répertoire de travail
WORKDIR /app

# Copie de tous les fichiers du contexte dans l'image Docker
COPY . /app/

# Installation des dépendances
RUN pip install --no-cache-dir -r requirements.txt

# Vérification que le fichier script.py existe
RUN ls -la /app

# Définition du point d'entrée de l'action
ENTRYPOINT ["python", "/app/script.py"]
