# -*- coding: utf-8 -*-
"""Test Llama 4 vision - save full output"""
import requests
import sys

GROQ_API_KEY = "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"

with open("test_output.txt", "w", encoding="utf-8") as f:
    f.write("Testing Llama 4 Scout\n")
    f.write("="*60 + "\n")
    
    # Test text only
    payload_text = {
        "model": "meta-llama/llama-4-scout-17b-16e-instruct",
        "messages": [{"role": "user", "content": "Say ciao"}],
        "max_tokens": 50
    }
    
    response = requests.post(
        "https://api.groq.com/openai/v1/chat/completions",
        headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
        json=payload_text,
        timeout=30
    )
    
    f.write(f"\nTEXT TEST - Status: {response.status_code}\n")
    f.write(f"Response: {response.text}\n")
    
    # Test vision with larger image from URL
    payload_vision = {
        "model": "meta-llama/llama-4-scout-17b-16e-instruct",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "What is in this image?"},
                    {"type": "image_url", "image_url": {"url": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/300px-PNG_transparency_demonstration_1.png"}}
                ]
            }
        ],
        "max_tokens": 100
    }
    
    response = requests.post(
        "https://api.groq.com/openai/v1/chat/completions",
        headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
        json=payload_vision,
        timeout=30
    )
    
    f.write(f"\nVISION TEST - Status: {response.status_code}\n")
    f.write(f"Response: {response.text}\n")
    
print("Results saved to test_output.txt")
