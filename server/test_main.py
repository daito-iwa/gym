#!/usr/bin/env python3
"""Test if main.py can be imported"""

try:
    print("Testing imports...")
    from fastapi import FastAPI
    print("✓ FastAPI imported")
    
    from fastapi.middleware.cors import CORSMiddleware
    print("✓ CORSMiddleware imported")
    
    from pydantic import BaseModel
    print("✓ BaseModel imported")
    
    import datetime
    print("✓ datetime imported")
    
    import main
    print("✓ main.py imported successfully")
    
    # Test endpoint
    from fastapi.testclient import TestClient
    client = TestClient(main.app)
    
    # Test health endpoint
    response = client.get("/health")
    print(f"✓ Health check: {response.status_code}")
    
    # Test chat endpoint
    response = client.post("/chat/message", json={"message": "test"})
    print(f"✓ Chat endpoint: {response.status_code}")
    print(f"  Response: {response.json()}")
    
except Exception as e:
    print(f"✗ Error: {type(e).__name__}: {e}")
    import traceback
    traceback.print_exc()