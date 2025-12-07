# -*- coding: utf-8 -*-
"""Test Groq Vision with real image"""
import requests
import base64
import sys
sys.stdout.reconfigure(encoding='utf-8')

GROQ_KEY = "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"

# Create a small but valid test image (100x100 gradient)
# This is a proper sized PNG that should pass Groq's size requirements
import struct
import zlib

def create_test_png():
    """Create a simple 100x100 blue PNG"""
    width, height = 100, 100
    
    # Create raw pixel data (RGBA)
    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'  # Filter byte
        for x in range(width):
            # Blue color
            raw_data += bytes([0, 100, 200, 255])
    
    # Compress
    compressed = zlib.compress(raw_data, 9)
    
    # Build PNG
    def png_chunk(chunk_type, data):
        chunk = chunk_type + data
        crc = zlib.crc32(chunk) & 0xffffffff
        return struct.pack('>I', len(data)) + chunk + struct.pack('>I', crc)
    
    png = b'\x89PNG\r\n\x1a\n'
    png += png_chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    png += png_chunk(b'IDAT', compressed)
    png += png_chunk(b'IEND', b'')
    
    return base64.b64encode(png).decode()

print("="*60)
print("Testing Groq Llama 4 with IMAGE")
print("="*60)

# Use a well-known test image URL instead
test_url = "https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png"

payload = {
    "model": "meta-llama/llama-4-scout-17b-16e-instruct",
    "messages": [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "What do you see in this image? Describe it briefly."},
                {"type": "image_url", "image_url": {"url": test_url}}
            ]
        }
    ],
    "max_tokens": 100
}

response = requests.post(
    "https://api.groq.com/openai/v1/chat/completions",
    headers={"Authorization": f"Bearer {GROQ_KEY}", "Content-Type": "application/json"},
    json=payload,
    timeout=30
)

print(f"Status: {response.status_code}")
print(f"Response: {response.text[:500]}")

if response.status_code == 200:
    data = response.json()
    content = data["choices"][0]["message"]["content"]
    print(f"\n[SUCCESS] Vision works!")
    print(f"AI says: {content}")
else:
    print(f"\n[FAILED] Vision doesn't work")
    
    # Try with base64
    print("\n\nTrying with base64 image...")
    test_b64 = create_test_png()
    
    payload2 = {
        "model": "meta-llama/llama-4-scout-17b-16e-instruct",
        "messages": [
            {
                "role": "user", 
                "content": [
                    {"type": "text", "text": "What color is this image?"},
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{test_b64}"}}
                ]
            }
        ],
        "max_tokens": 100
    }
    
    response2 = requests.post(
        "https://api.groq.com/openai/v1/chat/completions",
        headers={"Authorization": f"Bearer {GROQ_KEY}", "Content-Type": "application/json"},
        json=payload2,
        timeout=30
    )
    
    print(f"Base64 Status: {response2.status_code}")
    print(f"Base64 Response: {response2.text[:500]}")
