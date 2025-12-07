"""
Test Groq API for Llama Vision - FREE API!
Groq offers Llama 3.2 Vision models completely free with generous limits.
Get your free API key at: https://console.groq.com/keys
"""

import requests
import base64
import json

print("="*60)
print("GROQ API - Llama Vision Test (FREE!)")
print("="*60)
print("\n⚡ Groq offers FREE Llama Vision with 500k tokens/day!")
print("🔗 Get your free API key at: https://console.groq.com/keys\n")

GROQ_API_KEY = input("Enter your Groq API key (gsk_xxx...): ").strip()

if not GROQ_API_KEY:
    print("❌ No API key provided!")
    exit(1)

# Groq vision endpoint
url = "https://api.groq.com/openai/v1/chat/completions"

headers = {
    "Authorization": f"Bearer {GROQ_API_KEY}",
    "Content-Type": "application/json"
}

# Test with a simple 1x1 red pixel PNG image
test_image_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="

# Models to test - Groq's free vision models
models_to_test = [
    "llama-3.2-11b-vision-preview",
    "llama-3.2-90b-vision-preview",
]

def test_groq_vision(model_name: str):
    print(f"\n{'='*60}")
    print(f"Testing: {model_name}")
    print(f"{'='*60}")
    
    payload = {
        "model": model_name,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": "What color is this image? Reply in one word."
                    },
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/png;base64,{test_image_b64}"
                        }
                    }
                ]
            }
        ],
        "max_tokens": 100
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            content = data["choices"][0]["message"]["content"]
            print(f"✅ SUCCESS! Model responded: {content}")
            print(f"Usage: {data.get('usage', {})}")
            return True
        else:
            print(f"❌ Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

# Test all models
print("\n🚀 Testing Groq Vision Models...\n")

results = {}
for model in models_to_test:
    results[model] = test_groq_vision(model)

print("\n" + "="*60)
print("SUMMARY")
print("="*60)

working = [m for m, ok in results.items() if ok]
failed = [m for m, ok in results.items() if not ok]

if working:
    print(f"\n✅ Working models ({len(working)}):")
    for m in working:
        print(f"   - {m}")
        
if failed:
    print(f"\n❌ Failed models ({len(failed)}):")
    for m in failed:
        print(f"   - {m}")

if working:
    print("\n🎉 Groq API is working! You can use these models as fallback.")
    print("\nRecommended cascade:")
    print("  1. Gemini 2.5 Pro (primary)")
    print("  2. Groq llama-3.2-90b-vision-preview (fallback)")
    print("  3. Groq llama-3.2-11b-vision-preview (fallback)")
