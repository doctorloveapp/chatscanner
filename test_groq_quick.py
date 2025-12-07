# -*- coding: utf-8 -*-
"""Quick Groq API Test"""
import requests
import sys
sys.stdout.reconfigure(encoding='utf-8')

GROQ_API_KEY = "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"

url = "https://api.groq.com/openai/v1/chat/completions"

headers = {
    "Authorization": f"Bearer {GROQ_API_KEY}",
    "Content-Type": "application/json"
}

# Test image - 1x1 red pixel
test_image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="

models = [
    "llama-3.2-90b-vision-preview",
    "llama-3.2-11b-vision-preview",
]

print("="*60)
print("GROQ API Vision Test")
print("="*60)

for model in models:
    print(f"\nTesting: {model}")
    
    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "What color is this image? Reply in one word."},
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{test_image}"}}
                ]
            }
        ],
        "max_tokens": 50
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        print(f"  Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            content = data["choices"][0]["message"]["content"]
            print(f"  [SUCCESS] Response: {content}")
            print(f"  Tokens used: {data.get('usage', {})}")
        else:
            print(f"  [ERROR] {response.text[:200]}")
    except Exception as e:
        print(f"  [ERROR] {e}")

print("\n" + "="*60)
print("TEST COMPLETE")
print("="*60)
