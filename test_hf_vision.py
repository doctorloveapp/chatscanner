# -*- coding: utf-8 -*-
"""
Test HuggingFace Vision Models - Direct API Test
Tests Llama 3.2 11B Vision and Qwen2-VL-7B with your HF token
"""

import requests
import base64
import json
import os
import sys

# Fix Windows encoding
sys.stdout.reconfigure(encoding='utf-8')

print("="*60)
print("HuggingFace Vision Models - Direct API Test")
print("="*60)

# Try to read from .env file
hf_token = None
env_path = ".env"

if os.path.exists(env_path):
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("HF_TOKEN="):
                hf_token = line.split("=", 1)[1].strip().strip('"').strip("'")
                break

if not hf_token:
    hf_token = input("Enter your HuggingFace token (hf_xxx...): ").strip()

if not hf_token:
    print("[ERROR] No HF token found!")
    exit(1)

print(f"[OK] Using HF token: {hf_token[:15]}...")

# Test image - 1x1 red pixel
test_image_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="

# Models to test
models = [
    "meta-llama/Llama-3.2-11B-Vision-Instruct",
    "Qwen/Qwen2-VL-7B-Instruct",
]

def test_model(model_id):
    print(f"\n{'='*60}")
    print(f"Testing: {model_id}")
    print("="*60)
    
    url = f"https://api-inference.huggingface.co/models/{model_id}"
    
    headers = {
        "Authorization": f"Bearer {hf_token}",
        "Content-Type": "application/json"
    }
    
    # Try different payload formats
    payloads = [
        # Format 1: Standard vision format
        {
            "inputs": {
                "image": test_image_b64,
                "text": "What color is this image? Reply in one word."
            },
            "parameters": {"max_new_tokens": 50}
        },
        # Format 2: Messages format (like OpenAI)
        {
            "inputs": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "What color is this?"},
                        {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{test_image_b64}"}}
                    ]
                }
            ],
            "parameters": {"max_new_tokens": 50}
        },
        # Format 3: Simple inputs
        {
            "inputs": f"data:image/png;base64,{test_image_b64}",
            "parameters": {"max_new_tokens": 50}
        }
    ]
    
    for i, payload in enumerate(payloads, 1):
        print(f"\n  Trying format {i}...")
        
        try:
            response = requests.post(url, headers=headers, json=payload, timeout=60)
            
            print(f"  Status: {response.status_code}")
            
            if response.status_code == 200:
                print(f"  [SUCCESS] Format {i} works!")
                print(f"  Response: {response.text[:300]}")
                return {"model": model_id, "status": "working", "format": i}
                
            elif response.status_code == 503:
                resp = response.json()
                if "loading" in str(resp).lower():
                    estimated = resp.get("estimated_time", "unknown")
                    print(f"  [LOADING] Model loading... (wait ~{estimated}s)")
                    return {"model": model_id, "status": "loading", "time": estimated}
                else:
                    print(f"  [WARN] 503: {response.text[:200]}")
                    
            elif response.status_code == 401:
                print(f"  [ERROR] 401 Unauthorized - invalid token")
                return {"model": model_id, "status": "unauthorized"}
                
            elif response.status_code == 403:
                print(f"  [ERROR] 403 Forbidden - model requires Pro/agreement")
                print(f"  Response: {response.text[:200]}")
                return {"model": model_id, "status": "forbidden"}
                
            elif response.status_code == 422:
                print(f"  [WARN] 422 Wrong format: {response.text[:150]}")
                # Try next format
                continue
                
            else:
                print(f"  [ERROR] {response.status_code}: {response.text[:200]}")
                
        except Exception as e:
            print(f"  [ERROR] Exception: {e}")
    
    return {"model": model_id, "status": "failed"}


# Run tests
results = []
for model in models:
    result = test_model(model)
    results.append(result)

# Summary
print("\n\n" + "="*60)
print("SUMMARY")
print("="*60)

for r in results:
    status = r["status"]
    model = r["model"]
    
    if status == "working":
        print(f"[OK] {model} - WORKING (format {r.get('format')})")
    elif status == "loading":
        print(f"[WAIT] {model} - LOADING (wait {r.get('time')}s and retry)")
    elif status == "forbidden":
        print(f"[FAIL] {model} - REQUIRES PRO SUBSCRIPTION")
    elif status == "unauthorized":
        print(f"[FAIL] {model} - INVALID TOKEN")
    else:
        print(f"[FAIL] {model} - FAILED")

# Recommendations
working = [r for r in results if r["status"] == "working"]
loading = [r for r in results if r["status"] == "loading"]
failed = [r for r in results if r["status"] not in ["working", "loading"]]

if failed:
    print("\n[!] Some models failed. Recommendations:")
    print("   1. Use GROQ API (free) for Llama Vision: https://console.groq.com")
    print("   2. Or upgrade to HuggingFace Pro")
    print("   3. Or use only Gemini (already working)")
