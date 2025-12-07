# -*- coding: utf-8 -*-
"""Test all Groq models"""
import requests
import json
import sys
sys.stdout.reconfigure(encoding='utf-8')

GROQ_API_KEY = "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"

response = requests.get(
    "https://api.groq.com/openai/v1/models",
    headers={"Authorization": f"Bearer {GROQ_API_KEY}"}
)

if response.status_code == 200:
    models = response.json()
    with open("groq_models.json", "w") as f:
        json.dump(models, f, indent=2)
    print("Models saved to groq_models.json")
    
    # Print all model IDs
    for model in models.get("data", []):
        mid = model.get("id", "")
        print(mid)
else:
    print(f"Error: {response.status_code}")
    print(response.text)
