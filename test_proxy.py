#!/usr/bin/env python3
"""
Simple test script for the OpenAI proxy
"""

import requests
import time

def test_health():
    """Test the health endpoint"""
    try:
        response = requests.get("http://localhost:5050/health", timeout=5)
        if response.status_code == 200:
            print("✅ Health check passed")
            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except requests.RequestException as e:
        print(f"❌ Health check failed: {e}")
        return False

def test_proxy():
    """Test the proxy with a simple OpenAI API call"""
    try:
        # Test with OpenAI models endpoint (doesn't require API key)
        response = requests.get("http://localhost:5050/v1/models", timeout=10)
        if response.status_code in [200, 401]:  # 401 is expected without API key
            print("✅ Proxy test passed")
            return True
        else:
            print(f"❌ Proxy test failed: {response.status_code}")
            return False
    except requests.RequestException as e:
        print(f"❌ Proxy test failed: {e}")
        return False

if __name__ == "__main__":
    print("Testing OpenAI Proxy...")
    print("=" * 30)
    
    health_ok = test_health()
    proxy_ok = test_proxy()
    
    print("=" * 30)
    if health_ok and proxy_ok:
        print("🎉 All tests passed! Proxy is working correctly.")
    else:
        print("❌ Some tests failed. Check the proxy configuration.") 