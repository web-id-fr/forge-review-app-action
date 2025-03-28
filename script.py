import os
import sys
import json
import re
import requests

message = os.getenv("INPUT_ROOT_DOMAIN", "Hello depuis l'action!")

try:
    response = requests.get("https://api.github.com")
    api_status = response.status_code
except requests.RequestException as e:
    api_status = f"Erreur: {str(e)}"

data = {
    "message": message,
    "api_status": api_status
}
json_output = json.dumps(data, indent=4)

print(f"🚀 {json_output}")

with open(os.environ['GITHUB_OUTPUT'], 'a') as output_file:
    print(f"result={json_output}", file=output_file)
