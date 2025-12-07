"""
Test script to verify HuggingFace Inference API availability
for vision models: Llama-3.2-11B-Vision-Instruct and Qwen2-VL-7B-Instruct
"""

import requests
import base64
import json
import sys

# Your HuggingFace token - set this or use environment variable
HF_TOKEN = input("Enter your HuggingFace token (hf_xxx...): ").strip()

if not HF_TOKEN:
    print("❌ No token provided!")
    sys.exit(1)

headers = {
    "Authorization": f"Bearer {HF_TOKEN}",
    "Content-Type": "application/json"
}

# Models to test
models_to_test = [
    "meta-llama/Llama-3.2-11B-Vision-Instruct",
    "Qwen/Qwen2-VL-7B-Instruct",
    # Alternative models that might work with free API
    "Salesforce/blip-image-captioning-large",
    "microsoft/git-base",
    "nlpconnect/vit-gpt2-image-captioning",
]

def test_model_availability(model_id: str) -> dict:
    """Test if a model is available on HuggingFace Inference API"""
    print(f"\n{'='*60}")
    print(f"Testing: {model_id}")
    print(f"{'='*60}")
    
    url = f"https://api-inference.huggingface.co/models/{model_id}"
    
    # First, just check model metadata
    try:
        # Simple GET to check if model exists
        response = requests.get(
            f"https://huggingface.co/api/models/{model_id}",
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Model exists on HuggingFace")
            print(f"   Pipeline tag: {data.get('pipeline_tag', 'N/A')}")
            print(f"   Library: {data.get('library_name', 'N/A')}")
            print(f"   Downloads: {data.get('downloads', 'N/A')}")
            
            # Check if model has inference API widget
            has_inference = data.get('inference', 'unknown')
            print(f"   Inference API: {has_inference}")
        else:
            print(f"❌ Model not found: {response.status_code}")
            return {"model": model_id, "status": "not_found"}
    except Exception as e:
        print(f"❌ Error checking model: {e}")
        return {"model": model_id, "status": "error", "error": str(e)}
    
    # Now test actual inference
    print(f"\n   Testing inference endpoint...")
    
    # Create a simple test image (1x1 red pixel PNG)
    test_image_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
    
    try:
        # Try different request formats based on model type
        payload = {
            "inputs": {
                "image": test_image_b64,
                "text": "What is in this image?"
            },
            "parameters": {
                "max_new_tokens": 50
            }
        }
        
        response = requests.post(
            url,
            headers=headers,
            json=payload,
            timeout=60
        )
        
        print(f"   Status code: {response.status_code}")
        
        if response.status_code == 200:
            print(f"   ✅ SUCCESS! Model works with Inference API")
            print(f"   Response: {response.text[:200]}...")
            return {"model": model_id, "status": "working", "response": response.json()}
            
        elif response.status_code == 503:
            resp_json = response.json()
            if "loading" in str(resp_json).lower():
                print(f"   ⏳ Model is loading (cold start)")
                estimated = resp_json.get("estimated_time", "unknown")
                print(f"   Estimated time: {estimated}s")
                return {"model": model_id, "status": "loading", "estimated_time": estimated}
            else:
                print(f"   ⚠️ Service unavailable: {response.text[:200]}")
                return {"model": model_id, "status": "unavailable", "response": response.text}
                
        elif response.status_code == 400:
            print(f"   ⚠️ Bad request (wrong format or model needs different input)")
            print(f"   Response: {response.text[:300]}")
            return {"model": model_id, "status": "bad_request", "response": response.text}
            
        elif response.status_code == 401:
            print(f"   ❌ Unauthorized - check your token")
            return {"model": model_id, "status": "unauthorized"}
            
        elif response.status_code == 403:
            print(f"   ❌ Forbidden - model may require Pro subscription or agreement")
            print(f"   Response: {response.text[:300]}")
            return {"model": model_id, "status": "forbidden", "response": response.text}
            
        else:
            print(f"   ❌ Error: {response.status_code}")
            print(f"   Response: {response.text[:300]}")
            return {"model": model_id, "status": "error", "code": response.status_code, "response": response.text}
            
    except requests.Timeout:
        print(f"   ⏰ Request timed out (60s)")
        return {"model": model_id, "status": "timeout"}
    except Exception as e:
        print(f"   ❌ Exception: {e}")
        return {"model": model_id, "status": "exception", "error": str(e)}


def main():
    print("="*60)
    print("HuggingFace Inference API - Vision Models Test")
    print("="*60)
    
    results = []
    for model in models_to_test:
        result = test_model_availability(model)
        results.append(result)
    
    print("\n\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    
    working = [r for r in results if r["status"] == "working"]
    loading = [r for r in results if r["status"] == "loading"]
    failed = [r for r in results if r["status"] not in ["working", "loading"]]
    
    print(f"\n✅ Working models ({len(working)}):")
    for r in working:
        print(f"   - {r['model']}")
    
    print(f"\n⏳ Loading models ({len(loading)}):")
    for r in loading:
        print(f"   - {r['model']} (wait ~{r.get('estimated_time', '?')}s)")
    
    print(f"\n❌ Failed models ({len(failed)}):")
    for r in failed:
        print(f"   - {r['model']}: {r['status']}")
    
    # Save results
    with open("hf_test_results.json", "w") as f:
        json.dump(results, f, indent=2)
    print(f"\n📄 Results saved to hf_test_results.json")


if __name__ == "__main__":
    main()
