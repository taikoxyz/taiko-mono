import redis.asyncio as redis
from typing import Optional, Any, Union
import json
import structlog
from .config import settings

logger = structlog.get_logger()


class CacheService:
    def __init__(self):
        self.redis_client: Optional[redis.Redis] = None
        
    async def connect(self):
        """Connect to Redis"""
        try:
            self.redis_client = redis.from_url(
                settings.redis_url,
                encoding="utf-8",
                decode_responses=True,
                max_connections=settings.redis_pool_size
            )
            # Test connection
            await self.redis_client.ping()
            logger.info("Connected to Redis successfully")
        except Exception as e:
            logger.error("Failed to connect to Redis", error=str(e))
            self.redis_client = None
            
    async def disconnect(self):
        """Disconnect from Redis"""
        if self.redis_client:
            await self.redis_client.close()
            logger.info("Disconnected from Redis")
            
    async def get(self, key: str) -> Optional[Any]:
        """Get value from cache"""
        if not self.redis_client:
            return None
            
        try:
            value = await self.redis_client.get(key)
            if value:
                return json.loads(value)
            return None
        except Exception as e:
            logger.error("Cache get error", key=key, error=str(e))
            return None
            
    async def set(
        self, 
        key: str, 
        value: Any, 
        ttl: Optional[int] = None
    ) -> bool:
        """Set value in cache with optional TTL"""
        if not self.redis_client:
            return False
            
        try:
            serialized_value = json.dumps(value, default=str)
            if ttl:
                await self.redis_client.setex(key, ttl, serialized_value)
            else:
                await self.redis_client.set(key, serialized_value)
            return True
        except Exception as e:
            logger.error("Cache set error", key=key, error=str(e))
            return False
            
    async def delete(self, key: str) -> bool:
        """Delete key from cache"""
        if not self.redis_client:
            return False
            
        try:
            result = await self.redis_client.delete(key)
            return bool(result)
        except Exception as e:
            logger.error("Cache delete error", key=key, error=str(e))
            return False
            
    async def exists(self, key: str) -> bool:
        """Check if key exists in cache"""
        if not self.redis_client:
            return False
            
        try:
            result = await self.redis_client.exists(key)
            return bool(result)
        except Exception as e:
            logger.error("Cache exists error", key=key, error=str(e))
            return False
            
    async def increment(self, key: str, amount: int = 1) -> Optional[int]:
        """Increment counter in cache"""
        if not self.redis_client:
            return None
            
        try:
            result = await self.redis_client.incr(key, amount)
            return result
        except Exception as e:
            logger.error("Cache increment error", key=key, error=str(e))
            return None
            
    async def expire(self, key: str, ttl: int) -> bool:
        """Set expiration time for key"""
        if not self.redis_client:
            return False
            
        try:
            result = await self.redis_client.expire(key, ttl)
            return bool(result)
        except Exception as e:
            logger.error("Cache expire error", key=key, error=str(e))
            return False


# Global cache instance
cache = CacheService()


def get_cache_key(prefix: str, *args) -> str:
    """Generate cache key"""
    return f"{prefix}:{'_'.join(str(arg) for arg in args)}"


async def cached_agent_card(domain: str) -> Optional[dict]:
    """Get cached agent card"""
    key = get_cache_key("agent_card", domain)
    return await cache.get(key)


async def cache_agent_card(domain: str, agent_card: dict) -> bool:
    """Cache agent card"""
    key = get_cache_key("agent_card", domain)
    return await cache.set(key, agent_card, settings.agent_card_cache_ttl)


async def cached_feedback_list(page: int, page_size: int, **filters) -> Optional[dict]:
    """Get cached feedback list"""
    filter_str = "_".join(f"{k}={v}" for k, v in sorted(filters.items()) if v is not None)
    key = get_cache_key("feedback_list", page, page_size, filter_str)
    return await cache.get(key)


async def cache_feedback_list(page: int, page_size: int, data: dict, **filters) -> bool:
    """Cache feedback list"""
    filter_str = "_".join(f"{k}={v}" for k, v in sorted(filters.items()) if v is not None)
    key = get_cache_key("feedback_list", page, page_size, filter_str)
    return await cache.set(key, data, settings.feedback_list_cache_ttl)


async def cached_reputation_score(agent_address: str) -> Optional[dict]:
    """Get cached reputation score"""
    key = get_cache_key("reputation", agent_address)
    return await cache.get(key)


async def cache_reputation_score(agent_address: str, score_data: dict) -> bool:
    """Cache reputation score"""
    key = get_cache_key("reputation", agent_address)
    return await cache.set(key, score_data, settings.reputation_cache_ttl)


async def invalidate_agent_cache(agent_address: str, domain: str = None):
    """Invalidate all cache entries for an agent"""
    patterns = [
        get_cache_key("reputation", agent_address),
        get_cache_key("feedback_list", "*"),  # Invalidate all feedback lists
    ]
    
    if domain:
        patterns.append(get_cache_key("agent_card", domain))
    
    for pattern in patterns:
        if "*" in pattern:
            # For pattern-based deletion, we'd need to scan keys
            # For now, just delete specific keys
            continue
        await cache.delete(pattern)