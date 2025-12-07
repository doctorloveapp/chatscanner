# -*- coding: utf-8 -*-
"""Test both Gemini and Groq APIs"""
import requests
import json
import sys
sys.stdout.reconfigure(encoding='utf-8')

GEMINI_KEY = "AIzaSyAWw2VIlF53YRq0Pcg3UEAafux6NIycosk"
GROQ_KEY = "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"

results = []

# Test 1: Gemini 2.5 Pro (text only first)
print("="*60)
print("TEST 1: Gemini 2.5 Pro - Text")
print("="*60)
try:
    response = requests.post(
        f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key={GEMINI_KEY}",
        headers={"Content-Type": "application/json"},
        json={"contents": [{"parts": [{"text": "Say ciao"}]}]},
        timeout=30
    )
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        text = data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
        print(f"[OK] Response: {text[:100]}")
        results.append(("Gemini 2.5 Pro", "OK"))
    else:
        print(f"[ERROR] {response.text[:300]}")
        results.append(("Gemini 2.5 Pro", f"ERROR {response.status_code}"))
except Exception as e:
    print(f"[ERROR] {e}")
    results.append(("Gemini 2.5 Pro", str(e)))

# Test 2: Gemini 2.0 Flash (alternative)
print("\n" + "="*60)
print("TEST 2: Gemini 2.0 Flash - Text")
print("="*60)
try:
    response = requests.post(
        f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={GEMINI_KEY}",
        headers={"Content-Type": "application/json"},
        json={"contents": [{"parts": [{"text": "Say ciao"}]}]},
        timeout=30
    )
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        text = data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
        print(f"[OK] Response: {text[:100]}")
        results.append(("Gemini 2.0 Flash", "OK"))
    else:
        print(f"[ERROR] {response.text[:300]}")
        results.append(("Gemini 2.0 Flash", f"ERROR {response.status_code}"))
except Exception as e:
    print(f"[ERROR] {e}")
    results.append(("Gemini 2.0 Flash", str(e)))

# Test 3: Groq Llama 4 Scout (text only)
print("\n" + "="*60)
print("TEST 3: Groq Llama 4 Scout - Text")
print("="*60)
try:
    response = requests.post(
        "https://api.groq.com/openai/v1/chat/completions",
        headers={"Authorization": f"Bearer {GROQ_KEY}", "Content-Type": "application/json"},
        json={
            "model": "meta-llama/llama-4-scout-17b-16e-instruct",
            "messages": [{"role": "user", "content": "Say ciao"}],
            "max_tokens": 50
        },
        timeout=30
    )
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        text = data["choices"][0]["message"]["content"]
        print(f"[OK] Response: {text[:100]}")
        results.append(("Groq Llama 4 Scout", "OK"))
    else:
        print(f"[ERROR] {response.text[:300]}")
        results.append(("Groq Llama 4 Scout", f"ERROR {response.status_code}"))
except Exception as e:
    print(f"[ERROR] {e}")
    results.append(("Groq Llama 4 Scout", str(e)))

# Test 4: Groq Llama 3.3 70B (non-vision, as fallback)
print("\n" + "="*60)
print("TEST 4: Groq Llama 3.3 70B - Text")
print("="*60)
try:
    response = requests.post(
        "https://api.groq.com/openai/v1/chat/completions",
        headers={"Authorization": f"Bearer {GROQ_KEY}", "Content-Type": "application/json"},
        json={
            "model": "llama-3.3-70b-versatile",
            "messages": [{"role": "user", "content": "Say ciao"}],
            "max_tokens": 50
        },
        timeout=30
    )
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        text = data["choices"][0]["message"]["content"]
        print(f"[OK] Response: {text[:100]}")
        results.append(("Groq Llama 3.3 70B", "OK"))
    else:
        print(f"[ERROR] {response.text[:300]}")
        results.append(("Groq Llama 3.3 70B", f"ERROR {response.status_code}"))
except Exception as e:
    print(f"[ERROR] {e}")
    results.append(("Groq Llama 3.3 70B", str(e)))

# Summary
print("\n\n" + "="*60)
print("SUMMARY")
print("="*60)
for name, status in results:
    emoji = "[OK]" if status == "OK" else "[FAIL]"
    print(f"{emoji} {name}: {status}")
