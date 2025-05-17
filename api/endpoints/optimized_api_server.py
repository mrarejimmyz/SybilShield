"""
Optimized API server for AptosSybilShield

This module implements an optimized RESTful API for the AptosSybilShield project,
providing endpoints for Sybil detection, identity verification, and analytics.
Optimizations include efficient rate limiting, caching, batch processing, and asynchronous operations.
"""

import os
import logging
import json
import uuid
import time
import asyncio
import hashlib
import hmac
from typing import Dict, List, Any, Optional, Union
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Depends, Header, Request, BackgroundTasks, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel, Field, validator
import aiohttp
import redis.asyncio as redis
from functools import lru_cache

# Import project modules
# In a real implementation, these would be properly imported
# For hackathon purposes, we'll mock these imports
class MockImport:
    pass

# Mock imports
sybil_detection = MockImport()
identity_verification = MockImport()
indexer_integration = MockImport()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("api_server")

# Create FastAPI app with optimized settings
app = FastAPI(
    title="AptosSybilShield API",
    description="Optimized API for Sybil detection and identity verification on Aptos",
    version="1.1.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json"
)

# Add CORS middleware with more specific settings
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",  # Local development
        "https://aptossybilshield.com",  # Production domain
        "https://*.aptossybilshield.com"  # Subdomains
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    max_age=86400,  # Cache preflight requests for 24 hours
)

# Initialize Redis for distributed caching and rate limiting
# In a real implementation, this would connect to a Redis server
# For hackathon purposes, we'll simulate Redis functionality
class MockRedis:
    def __init__(self):
        self.data = {}
        self.expiry = {}
    
    async def get(self, key):
        if key in self.data and (key not in self.expiry or self.expiry[key] > time.time()):
            return self.data[key]
        return None
    
    async def set(self, key, value, ex=None):
        self.data[key] = value
        if ex:
            self.expiry[key] = time.time() + ex
    
    async def incr(self, key):
        if key not in self.data:
            self.data[key] = 1
        else:
            self.data[key] += 1
        return self.data[key]
    
    async def expire(self, key, seconds):
        self.expiry[key] = time.time() + seconds
    
    async def delete(self, key):
        if key in self.data:
            del self.data[key]
        if key in self.expiry:
            del self.expiry[key]

# Initialize mock Redis
redis_client = MockRedis()

# Token bucket rate limiter
class TokenBucketRateLimiter:
    """Efficient token bucket rate limiter implementation"""
    
    def __init__(self, redis_client):
        self.redis = redis_client
    
    async def consume(self, key: str, tokens: int, rate: float, capacity: float) -> bool:
        """
        Consume tokens from the bucket.
        
        Args:
            key: Unique identifier for the bucket
            tokens: Number of tokens to consume
            rate: Token refill rate per second
            capacity: Maximum bucket capacity
            
        Returns:
            True if tokens were consumed, False if not enough tokens
        """
        # Get current bucket state
        bucket_key = f"ratelimit:{key}"
        bucket_json = await self.redis.get(bucket_key)
        
        now = time.time()
        
        if bucket_json:
            bucket = json.loads(bucket_json)
            tokens_available = bucket["tokens"]
            last_refill = bucket["last_refill"]
            
            # Refill tokens based on elapsed time
            elapsed = now - last_refill
            new_tokens = min(capacity, tokens_available + (elapsed * rate))
            
            # Check if enough tokens are available
            if new_tokens < tokens:
                return False
            
            # Consume tokens
            bucket = {
                "tokens": new_tokens - tokens,
                "last_refill": now
            }
        else:
            # Initialize new bucket
            if tokens > capacity:
                return False
            
            bucket = {
                "tokens": capacity - tokens,
                "last_refill": now
            }
        
        # Save updated bucket
        await self.redis.set(bucket_key, json.dumps(bucket), ex=int(capacity / rate * 2))
        return True

# Initialize rate limiter
rate_limiter = TokenBucketRateLimiter(redis_client)

# API key storage with Redis
# In production, this would use a proper database
api_keys = {
    "test_api_key": {
        "user_id": "test_user",
        "rate_limit": 100,  # requests per minute
        "created_at": datetime.now().isoformat()
    }
}

# Webhook subscriptions
webhooks = {}

# Models for request/response with enhanced validation
class ApiKeyRequest(BaseModel):
    user_id: str = Field(..., description="User ID for the API key", min_length=3, max_length=50)
    rate_limit: int = Field(100, description="Rate limit in requests per minute", ge=1, le=1000)
    
    @validator('user_id')
    def validate_user_id(cls, v):
        if not v.isalnum():
            raise ValueError('user_id must be alphanumeric')
        return v

class ApiKeyResponse(BaseModel):
    api_key: str = Field(..., description="Generated API key")
    user_id: str = Field(..., description="User ID for the API key")
    rate_limit: int = Field(..., description="Rate limit in requests per minute")
    created_at: str = Field(..., description="Creation timestamp")

class SybilCheckRequest(BaseModel):
    address: str = Field(..., description="Aptos address to check", min_length=10)
    threshold: Optional[int] = Field(70, description="Risk threshold (0-100)", ge=0, le=100)
    include_features: Optional[bool] = Field(False, description="Whether to include feature details")
    
    @validator('address')
    def validate_address(cls, v):
        if not (v.startswith('0x') and len(v) >= 10):
            raise ValueError('address must be a valid Aptos address starting with 0x')
        return v

class SybilCheckResponse(BaseModel):
    address: str = Field(..., description="Checked address")
    is_sybil: bool = Field(..., description="Whether the address is flagged as Sybil")
    risk_score: int = Field(..., description="Risk score (0-100)")
    confidence: int = Field(..., description="Confidence level (0-100)")
    verification_status: str = Field(..., description="Verification status")
    request_id: str = Field(..., description="Unique request ID")
    timestamp: str = Field(..., description="Timestamp of the check")

class VerificationRequest(BaseModel):
    address: str = Field(..., description="Aptos address to verify", min_length=10)
    verification_type: str = Field(..., description="Type of verification")
    callback_url: Optional[str] = Field(None, description="Callback URL for verification completion")
    
    @validator('verification_type')
    def validate_verification_type(cls, v):
        valid_types = ["social_twitter", "social_github", "did_web", "pop_captcha", "kyc_basic"]
        if v not in valid_types:
            raise ValueError(f'verification_type must be one of: {", ".join(valid_types)}')
        return v
    
    @validator('callback_url')
    def validate_callback_url(cls, v):
        if v is not None and not (v.startswith('http://') or v.startswith('https://')):
            raise ValueError('callback_url must be a valid HTTP or HTTPS URL')
        return v

class VerificationResponse(BaseModel):
    verification_id: str = Field(..., description="Unique verification ID")
    address: str = Field(..., description="Address being verified")
    verification_type: str = Field(..., description="Type of verification")
    status: str = Field(..., description="Verification status")
    instructions: str = Field(..., description="Instructions for completing verification")
    expires_at: str = Field(..., description="Expiration timestamp")

class VerificationStatusResponse(BaseModel):
    verification_id: str = Field(..., description="Unique verification ID")
    address: str = Field(..., description="Address being verified")
    verification_type: str = Field(..., description="Type of verification")
    status: str = Field(..., description="Verification status")
    timestamp: str = Field(..., description="Timestamp of the status check")

class VerificationCompleteRequest(BaseModel):
    proof: Any = Field(..., description="Verification proof")

class WebhookSubscriptionRequest(BaseModel):
    event_types: List[str] = Field(..., description="Event types to subscribe to")
    url: str = Field(..., description="Webhook URL")
    secret: Optional[str] = Field(None, description="Webhook secret for signature verification")
    
    @validator('event_types')
    def validate_event_types(cls, v):
        valid_types = ["verification_complete", "sybil_detected", "risk_score_change"]
        for event_type in v:
            if event_type not in valid_types:
                raise ValueError(f'event_types must be from: {", ".join(valid_types)}')
        return v
    
    @validator('url')
    def validate_url(cls, v):
        if not (v.startswith('http://') or v.startswith('https://')):
            raise ValueError('url must be a valid HTTP or HTTPS URL')
        return v

class WebhookSubscriptionResponse(BaseModel):
    subscription_id: str = Field(..., description="Unique subscription ID")
    event_types: List[str] = Field(..., description="Subscribed event types")
    url: str = Field(..., description="Webhook URL")
    created_at: str = Field(..., description="Creation timestamp")

class BatchCheckRequest(BaseModel):
    addresses: List[str] = Field(..., description="List of addresses to check", min_items=1, max_items=100)
    threshold: Optional[int] = Field(70, description="Risk threshold (0-100)", ge=0, le=100)
    
    @validator('addresses')
    def validate_addresses(cls, v):
        for address in v:
            if not (address.startswith('0x') and len(address) >= 10):
                raise ValueError(f'address {address} must be a valid Aptos address starting with 0x')
        return v

class BatchCheckResponse(BaseModel):
    results: Dict[str, Any] = Field(..., description="Results for each address")
    request_id: str = Field(..., description="Unique request ID")
    timestamp: str = Field(..., description="Timestamp of the check")

# Enhanced dependency for API key validation with token bucket rate limiting
async def validate_api_key(
    request: Request,
    api_key: str = Header(..., description="API key for authentication")
):
    if api_key not in api_keys:
        raise HTTPException(status_code=401, detail="Invalid API key")
    
    # Get rate limit for this API key
    rate_limit = api_keys[api_key]["rate_limit"]
    
    # Check rate limit using token bucket algorithm
    if not await rate_limiter.consume(
        key=f"api:{api_key}",
        tokens=1,
        rate=rate_limit / 60,  # Convert from per minute to per second
        capacity=rate_limit
    ):
        raise HTTPException(status_code=429, detail="Rate limit exceeded")
    
    # Store API key in request state for logging
    request.state.api_key = api_key
    
    return api_key

# Middleware for request logging and timing
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    
    # Generate request ID
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    
    # Log request
    logger.info(f"Request {request_id}: {request.method} {request.url.path}")
    
    # Process request
    response = await call_next(request)
    
    # Calculate duration
    duration = time.time() - start_time
    
    # Log response
    logger.info(f"Response {request_id}: {response.status_code} ({duration:.3f}s)")
    
    # Add request ID and timing headers
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Response-Time"] = f"{duration:.3f}s"
    
    return response

# Startup and shutdown events
@app.on_event("startup")
async def startup_event():
    logger.info("Starting optimized API server")
    
    # In a real implementation, this would initialize connections to databases, etc.
    # For hackathon purposes, we'll just log it

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Shutting down API server")
    
    # In a real implementation, this would close connections, etc.
    # For hackathon purposes, we'll just log it

# API key management
@app.post("/api/keys", response_model=ApiKeyResponse)
async def create_api_key(request: ApiKeyRequest):
    """Create a new API key"""
    api_key = f"ask_{uuid.uuid4().hex}"
    
    api_keys[api_key] = {
        "user_id": request.user_id,
        "rate_limit": request.rate_limit,
        "created_at": datetime.now().isoformat()
    }
    
    # In a real implementation, this would store the API key in a database
    # For hackathon purposes, we'll use the in-memory dictionary
    
    return {
        "api_key": api_key,
        "user_id": request.user_id,
        "rate_limit": request.rate_limit,
        "created_at": api_keys[api_key]["created_at"]
    }

# Optimized caching decorator
def cached(ttl_seconds: int = 300):
    """
    Decorator for caching endpoint responses.
    
    Args:
        ttl_seconds: Time-to-live in seconds for cache entries
    """
    def decorator(func):
        async def wrapper(*args, **kwargs):
            # Generate cache key from function name and arguments
            key_parts = [func.__name__]
            for arg in args:
                if hasattr(arg, "__dict__"):
                    key_parts.append(str(arg.__dict__))
                else:
                    key_parts.append(str(arg))
            for k, v in kwargs.items():
                if hasattr(v, "__dict__"):
                    key_parts.append(f"{k}:{str(v.__dict__)}")
                else:
                    key_parts.append(f"{k}:{str(v)}")
            
            cache_key = f"cache:{hashlib.md5(':'.join(key_parts).encode()).hexdigest()}"
            
            # Check cache
            cached_result = await redis_client.get(cache_key)
            if cached_result:
                return json.loads(cached_result)
            
            # Call original function
            result = await func(*args, **kwargs)
            
            # Cache result
            await redis_client.set(cache_key, json.dumps(result), ex=ttl_seconds)
            
            return result
        return wrapper
    return decorator

# Sybil detection endpoints
@app.post("/api/check", response_model=SybilCheckResponse)
@cached(ttl_seconds=60)  # Cache results for 1 minute
async def check_address(
    request: SybilCheckRequest, 
    api_key: str = Depends(validate_api_key)
):
    """Check if an address is a potential Sybil"""
    # In a real implementation, this would call the Sybil detection module
    # For hackathon purposes, we'll simulate a response
    
    # Generate a deterministic but random-looking result based on the address
    address_hash = hash(request.address)
    is_sybil = (address_hash % 100) > (100 - request.threshold)
    risk_score = abs(address_hash) % 100
    confidence = 70 + (abs(address_hash) % 30)
    
    # Check if address has been verified
    verification_status = "unverified"
    if abs(address_hash) % 3 == 0:
        verification_status = "verified"
    elif abs(address_hash) % 3 == 1:
        verification_status = "pending"
    
    request_id = f"req_{uuid.uuid4().hex}"
    timestamp = datetime.now().isoformat()
    
    # Cache the result in Redis
    result = {
        "address": request.address,
        "is_sybil": is_sybil,
        "risk_score": risk_score,
        "confidence": confidence,
        "verification_status": verification_status,
        "request_id": request_id,
        "timestamp": timestamp
    }
    
    await redis_client.set(f"result:{request_id}", json.dumps(result), ex=3600)  # 1 hour TTL
    
    return result

@app.post("/api/batch-check", response_model=BatchCheckResponse)
async def batch_check_addresses(
    request: BatchCheckRequest, 
    api_key: str = Depends(validate_api_key)
):
    """Check multiple addresses for potential Sybils in parallel"""
    results = {}
    
    # Process addresses in parallel
    async def process_address(address):
        # Similar logic to single check
        address_hash = hash(address)
        is_sybil = (address_hash % 100) > (100 - request.threshold)
        risk_score = abs(address_hash) % 100
        confidence = 70 + (abs(address_hash) % 30)
        
        verification_status = "unverified"
        if abs(address_hash) % 3 == 0:
            verification_status = "verified"
        elif abs(address_hash) % 3 == 1:
            verification_status = "pending"
        
        return address, {
            "is_sybil": is_sybil,
            "risk_score": risk_score,
            "confidence": confidence,
            "verification_status": verification_status
        }
    
    # Create tasks for all addresses
    tasks = [process_address(address) for address in request.addresses]
    
    # Run all tasks concurrently
    for task in asyncio.as_completed(tasks):
        address, result = await task
        results[address] = result
    
    request_id = f"batch_{uuid.uuid4().hex}"
    timestamp = datetime.now().isoformat()
    
    # Cache the batch result
    batch_result = {
        "results": results,
        "request_id": request_id,
        "timestamp": timestamp
    }
    
    await redis_client.set(f"batch:{request_id}", json.dumps(batch_result), ex=3600)  # 1 hour TTL
    
    return batch_result

@app.get("/api/check/{request_id}")
async def get_check_result(
    request_id: str, 
    api_key: str = Depends(validate_api_key)
):
    """Get the result of a previous check"""
    # Try to get from Redis
    result_json = await redis_client.get(f"result:{request_id}")
    
    if not result_json:
        # Try batch results
        batch_json = await redis_client.get(f"batch:{request_id}")
        if not batch_json:
            raise HTTPException(status_code=404, detail="Request ID not found")
        return json.loads(batch_json)
    
    return json.loads(result_json)

# Verification endpoints
@app.post("/api/verify", response_model=VerificationResponse)
async def start_verification(
    request: VerificationRequest, 
    api_key: str = Depends(validate_api_key)
):
    """Start the verification process for an address"""
    # In a real implementation, this would call the identity verification module
    # For hackathon purposes, we'll simulate a response
    
    verification_id = f"ver_{uuid.uuid4().hex}"
    
    # Generate instructions based on verification type
    instructions = "Default verification instructions"
    if request.verification_type == "social_twitter":
        instructions = "Post a specific message on Twitter with the following content: 'Verifying my Aptos address with AptosSybilShield: " + verification_id[:8] + "'"
    elif request.verification_type == "social_github":
        instructions = "Create a public gist with filename 'aptos_verification.txt' containing: 'Verifying my Aptos address with AptosSybilShield: " + verification_id[:8] + "'"
    elif request.verification_type == "did_web":
        instructions = "Create a DID document at /.well-known/did.json on your web domain with the following content: " + json.dumps({"verification": verification_id[:8]})
    elif request.verification_type == "pop_captcha":
        instructions = "Solve the CAPTCHA challenge at https://aptossybilshield.com/captcha/" + verification_id[:8]
    elif request.verification_type == "kyc_basic":
        instructions = "Complete the KYC process at https://aptossybilshield.com/kyc/" + verification_id[:8]
    
    # Set expiration (24 hours from now)
    expires_at = (datetime.now() + timedelta(hours=24)).isoformat()
    
    # Store verification request in Redis
    verification_data = {
        "address": request.address,
        "verification_type": request.verification_type,
        "status": "pending",
        "instructions": instructions,
        "expires_at": expires_at,
        "callback_url": request.callback_url
    }
    
    await redis_client.set(
        f"verification:{verification_id}", 
        json.dumps(verification_data), 
        ex=86400  # 24 hours TTL
    )
    
    return {
        "verification_id": verification_id,
        "address": request.address,
        "verification_type": request.verification_type,
        "status": "pending",
        "instructions": instructions,
        "expires_at": expires_at
    }

@app.get("/api/verify/{verification_id}", response_model=VerificationStatusResponse)
async def check_verification_status(
    verification_id: str, 
    api_key: str = Depends(validate_api_key)
):
    """Check the status of a verification process"""
    # Get from Redis
    verification_json = await redis_client.get(f"verification:{verification_id}")
    
    if not verification_json:
        raise HTTPException(status_code=404, detail="Verification ID not found")
    
    verification = json.loads(verification_json)
    
    return {
        "verification_id": verification_id,
        "address": verification["address"],
        "verification_type": verification["verification_type"],
        "status": verification["status"],
        "timestamp": datetime.now().isoformat()
    }

@app.post("/api/verify/{verification_id}/complete")
async def complete_verification(
    verification_id: str, 
    request: VerificationCompleteRequest, 
    background_tasks: BackgroundTasks,
    api_key: str = Depends(validate_api_key)
):
    """Complete the verification process"""
    # Get from Redis
    verification_json = await redis_client.get(f"verification:{verification_id}")
    
    if not verification_json:
        raise HTTPException(status_code=404, detail="Verification ID not found")
    
    verification = json.loads(verification_json)
    
    # Check if expired
    if datetime.fromisoformat(verification["expires_at"]) < datetime.now():
        raise HTTPException(status_code=400, detail="Verification expired")
    
    # In a real implementation, this would validate the proof
    # For hackathon purposes, we'll simulate success
    verification["status"] = "verified"
    verification["verified_at"] = datetime.now().isoformat()
    verification["proof"] = request.proof
    
    # Update in Redis
    await redis_client.set(
        f"verification:{verification_id}", 
        json.dumps(verification), 
        ex=86400  # 24 hours TTL
    )
    
    # If callback URL was provided, send webhook asynchronously
    if verification["callback_url"]:
        background_tasks.add_task(
            send_webhook, 
            verification["callback_url"], 
            {
                "event": "verification_complete",
                "verification_id": verification_id,
                "address": verification["address"],
                "status": "verified",
                "timestamp": verification["verified_at"]
            }
        )
    
    return {
        "verification_id": verification_id,
        "address": verification["address"],
        "verification_type": verification["verification_type"],
        "status": "verified",
        "timestamp": verification["verified_at"]
    }

# Webhook endpoints
@app.post("/api/webhooks", response_model=WebhookSubscriptionResponse)
async def subscribe_webhook(
    request: WebhookSubscriptionRequest, 
    api_key: str = Depends(validate_api_key)
):
    """Subscribe to webhook notifications"""
    subscription_id = f"sub_{uuid.uuid4().hex}"
    
    # Store in Redis
    webhook_data = {
        "event_types": request.event_types,
        "url": request.url,
        "secret": request.secret,
        "api_key": api_key,
        "created_at": datetime.now().isoformat()
    }
    
    await redis_client.set(
        f"webhook:{subscription_id}", 
        json.dumps(webhook_data), 
        ex=31536000  # 1 year TTL
    )
    
    return {
        "subscription_id": subscription_id,
        "event_types": request.event_types,
        "url": request.url,
        "created_at": webhook_data["created_at"]
    }

@app.delete("/api/webhooks/{subscription_id}")
async def unsubscribe_webhook(
    subscription_id: str, 
    api_key: str = Depends(validate_api_key)
):
    """Unsubscribe from webhook notifications"""
    # Get from Redis
    webhook_json = await redis_client.get(f"webhook:{subscription_id}")
    
    if not webhook_json:
        raise HTTPException(status_code=404, detail="Subscription ID not found")
    
    webhook = json.loads(webhook_json)
    
    # Check if the API key matches
    if webhook["api_key"] != api_key:
        raise HTTPException(status_code=403, detail="Not authorized to delete this subscription")
    
    # Delete from Redis
    await redis_client.delete(f"webhook:{subscription_id}")
    
    return {"status": "unsubscribed"}

# Optimized webhook sending with retries and signature
async def send_webhook(url: str, data: Dict[str, Any], secret: Optional[str] = None, max_retries: int = 3):
    """
    Send webhook notification with retries and signature.
    
    Args:
        url: Webhook URL
        data: Data to send
        secret: Optional secret for signing the payload
        max_retries: Maximum number of retry attempts
    """
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "AptosSybilShield-Webhook/1.0",
        "X-Webhook-Timestamp": str(int(time.time()))
    }
    
    # Add signature if secret is provided
    if secret:
        payload = json.dumps(data)
        signature = hmac.new(
            secret.encode(),
            payload.encode(),
            hashlib.sha256
        ).hexdigest()
        headers["X-Webhook-Signature"] = signature
    
    # Send with retries
    async with aiohttp.ClientSession() as session:
        for attempt in range(max_retries):
            try:
                async with session.post(url, json=data, headers=headers, timeout=10) as response:
                    if response.status < 400:
                        logger.info(f"Webhook sent successfully to {url}")
                        return
                    
                    logger.warning(f"Webhook to {url} failed with status {response.status}")
                    
                    # Don't retry for client errors (except 429)
                    if 400 <= response.status < 500 and response.status != 429:
                        return
            except Exception as e:
                logger.warning(f"Webhook to {url} failed: {str(e)}")
            
            # Exponential backoff
            if attempt < max_retries - 1:
                await asyncio.sleep(2 ** attempt)
        
        logger.error(f"Webhook to {url} failed after {max_retries} attempts")

# Health check endpoint with enhanced information
@app.get("/health")
async def health_check():
    """Health check endpoint with system status"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.1.0",
        "uptime": time.time() - app.state.start_time if hasattr(app.state, "start_time") else 0
    }

# Store start time for uptime calculation
@app.on_event("startup")
async def set_start_time():
    app.state.start_time = time.time()

# Main entry point
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "api_server:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        workers=4,
        log_level="info"
    )
