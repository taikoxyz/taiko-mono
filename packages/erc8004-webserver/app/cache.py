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
        ttl: Optional[int] = None,
        tags: Optional[list] = None
    ) -> bool:
        """Set value in cache with optional TTL and tags"""
        if not self.redis_client:
            return False
            
        try:
            serialized_value = json.dumps(value, default=str)
            if ttl:
                await self.redis_client.setex(key, ttl, serialized_value)
            else:
                await self.redis_client.set(key, serialized_value)
            
            # Add to tag sets for cache invalidation
            if tags:
                for tag in tags:
                    tag_set = f"tag:{tag}"
                    await self.redis_client.sadd(tag_set, key)
                    if ttl:
                        await self.redis_client.expire(tag_set, ttl + 60)  # Tag expires slightly after cache
            
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
    
    async def delete_pattern(self, pattern: str) -> int:
        """Delete all keys matching a pattern"""
        if not self.redis_client:
            return 0
            
        try:
            # Use SCAN to find keys matching pattern
            keys_to_delete = []
            async for key in self.redis_client.scan_iter(match=pattern):
                keys_to_delete.append(key)
            
            # Delete keys in batches to avoid blocking Redis
            if keys_to_delete:
                batch_size = 100
                deleted_count = 0
                for i in range(0, len(keys_to_delete), batch_size):
                    batch = keys_to_delete[i:i + batch_size]
                    deleted = await self.redis_client.delete(*batch)
                    deleted_count += deleted
                
                logger.info("Pattern cache deletion", pattern=pattern, deleted_count=deleted_count)
                return deleted_count
            return 0
        except Exception as e:
            logger.error("Cache pattern delete error", pattern=pattern, error=str(e))
            return 0
    
    async def invalidate_by_tag(self, tag: str) -> int:
        """Invalidate all cache entries with a specific tag"""
        if not self.redis_client:
            return 0
            
        try:
            tag_set = f"tag:{tag}"
            # Get all keys with this tag
            keys_to_delete = await self.redis_client.smembers(tag_set)
            
            if keys_to_delete:
                # Delete the cache entries
                deleted = await self.redis_client.delete(*keys_to_delete)
                # Delete the tag set
                await self.redis_client.delete(tag_set)
                
                logger.info("Tag-based cache invalidation", tag=tag, deleted_count=deleted)
                return deleted
            return 0
        except Exception as e:
            logger.error("Cache tag invalidation error", tag=tag, error=str(e))
            return 0
            
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
    return await cache.set(key, data, settings.feedback_list_cache_ttl, tags=["feedback"])


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
    # Delete specific keys
    await cache.delete(get_cache_key("reputation", agent_address))
    
    if domain:
        await cache.delete(get_cache_key("agent_card", domain))
    
    # Invalidate all feedback lists using tag-based invalidation
    await cache.invalidate_by_tag("feedback")


async def invalidate_feedback_cache():
    """Invalidate all feedback-related cache entries"""
    await cache.invalidate_by_tag("feedback")


async def invalidate_reputation_cache(agent_address: str = None):
    """Invalidate reputation cache entries"""
    if agent_address:
        await cache.delete(get_cache_key("reputation", agent_address))
    else:
        # Invalidate all reputation entries by pattern
        await cache.delete_pattern("reputation:*")