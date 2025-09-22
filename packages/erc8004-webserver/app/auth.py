from fastapi import HTTPException, Security, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional, Dict, Any
import structlog
from datetime import datetime, timedelta
import hashlib
import time

from .web3_service import web3_service
from .cache import cache
from .config import settings

logger = structlog.get_logger()
security = HTTPBearer()


class AuthenticationError(HTTPException):
    def __init__(self, detail: str):
        super().__init__(status_code=401, detail=detail)


class AuthorizationError(HTTPException):
    def __init__(self, detail: str):
        super().__init__(status_code=403, detail=detail)


async def verify_signature_auth(
    authorization: HTTPAuthorizationCredentials = Security(security),
    agent_address: str = None,
    signature: str = None
) -> Dict[str, Any]:
    """
    Verify Ethereum signature authentication
    
    Expected headers:
    - Authorization: Bearer <message_to_be_signed>
    - Agent-Address: <CAIP-10_address>  
    - Signature: <ethereum_signature>
    """
    if not authorization:
        raise AuthenticationError("Missing authorization header")
    
    message = authorization.credentials
    
    if not agent_address:
        raise AuthenticationError("Missing Agent-Address header")
    
    if not signature:
        raise AuthenticationError("Missing Signature header")
    
    # Parse agent address from CAIP-10 format
    parsed_address, chain_id = web3_service.parse_caip10_address(agent_address)
    if not parsed_address:
        raise AuthenticationError("Invalid agent address format")
    
    # Verify signature
    if not web3_service.verify_signature(message, signature, parsed_address):
        raise AuthenticationError("Invalid signature")
    
    # Check for signature replay attacks
    signature_hash = hashlib.sha256(f"{signature}{message}{parsed_address}".encode()).hexdigest()
    replay_key = f"signature_replay:{signature_hash}"
    
    if await cache.exists(replay_key):
        raise AuthenticationError("Signature already used (replay attack prevention)")
    
    # Store signature hash for replay prevention (expire in 1 hour)
    await cache.set(replay_key, True, ttl=3600)
    
    return {
        "agent_address": agent_address,
        "parsed_address": parsed_address,
        "chain_id": chain_id,
        "message": message,
        "signature": signature,
        "authenticated_at": datetime.utcnow()
    }


async def verify_eip712_auth(
    structured_data: Dict[str, Any],
    authorization: HTTPAuthorizationCredentials = Security(security),
    agent_address: str = None,
    signature: str = None
) -> Dict[str, Any]:
    """Verify EIP-712 structured data signature"""
    
    if not authorization:
        raise AuthenticationError("Missing authorization header")
    
    if not agent_address:
        raise AuthenticationError("Missing Agent-Address header")
    
    if not signature:
        raise AuthenticationError("Missing Signature header")
    
    # Parse agent address from CAIP-10 format
    parsed_address, chain_id = web3_service.parse_caip10_address(agent_address)
    if not parsed_address:
        raise AuthenticationError("Invalid agent address format")
    
    # Verify EIP-712 signature
    if not web3_service.verify_eip712_signature(structured_data, signature, parsed_address):
        raise AuthenticationError("Invalid EIP-712 signature")
    
    # Check for signature replay attacks
    signature_hash = hashlib.sha256(f"{signature}{str(structured_data)}{parsed_address}".encode()).hexdigest()
    replay_key = f"eip712_replay:{signature_hash}"
    
    if await cache.exists(replay_key):
        raise AuthenticationError("Signature already used (replay attack prevention)")
    
    # Store signature hash for replay prevention (expire in 1 hour)
    await cache.set(replay_key, True, ttl=3600)
    
    return {
        "agent_address": agent_address,
        "parsed_address": parsed_address,
        "chain_id": chain_id,
        "structured_data": structured_data,
        "signature": signature,
        "authenticated_at": datetime.utcnow()
    }


class RateLimiter:
    """Rate limiting using Redis"""
    
    def __init__(self):
        self.window_size = 60  # 1 minute window
    
    async def check_rate_limit(
        self, 
        key: str, 
        limit: int, 
        window: int = None
    ) -> bool:
        """Check if request is within rate limit"""
        if not settings.rate_limit_enabled:
            return True
        
        window = window or self.window_size
        current_time = int(time.time())
        window_start = current_time - window
        
        # Use Redis sorted set for sliding window rate limiting
        rate_key = f"rate_limit:{key}"
        
        try:
            # Remove old entries
            await cache.redis_client.zremrangebyscore(rate_key, 0, window_start)
            
            # Count current requests
            current_count = await cache.redis_client.zcard(rate_key)
            
            if current_count >= limit:
                return False
            
            # Add current request
            await cache.redis_client.zadd(rate_key, {str(current_time): current_time})
            await cache.redis_client.expire(rate_key, window)
            
            return True
            
        except Exception as e:
            logger.error("Rate limiting error", error=str(e))
            # In case of Redis error, allow request to proceed
            return True
    
    async def get_rate_limit_key(
        self, 
        client_ip: str, 
        agent_address: str = None, 
        endpoint: str = None
    ) -> str:
        """Generate rate limit key"""
        if agent_address:
            return f"{agent_address}:{endpoint or 'api'}"
        return f"{client_ip}:{endpoint or 'api'}"


rate_limiter = RateLimiter()


async def apply_rate_limit(
    client_ip: str,
    agent_address: str = None,
    endpoint: str = None,
    is_authenticated: bool = False
) -> None:
    """Apply rate limiting"""
    
    # Determine rate limit
    if is_authenticated:
        limit = int(settings.rate_limit_authenticated.split('/')[0])
    else:
        limit = int(settings.rate_limit_public.split('/')[0])
    
    # Generate rate limit key
    key = await rate_limiter.get_rate_limit_key(client_ip, agent_address, endpoint)
    
    # Check rate limit
    if not await rate_limiter.check_rate_limit(key, limit):
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded",
            headers={"Retry-After": "60"}
        )


def extract_client_ip(request) -> str:
    """Extract client IP from request"""
    # Check for forwarded headers (from load balancer/proxy)
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(',')[0].strip()
    
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip
    
    return request.client.host if request.client else "unknown"