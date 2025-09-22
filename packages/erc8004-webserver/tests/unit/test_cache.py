import pytest
from unittest.mock import AsyncMock, Mock
import json

from app.cache import CacheService, get_cache_key, cached_agent_card, cache_agent_card


class TestCacheService:
    
    @pytest.mark.asyncio
    async def test_connect_success(self):
        """Test successful cache connection."""
        cache_service = CacheService()
        
        # Mock Redis
        mock_redis = AsyncMock()
        mock_redis.ping.return_value = True
        
        with pytest.MonkeyPatch().context() as m:
            m.setattr('redis.asyncio.from_url', Mock(return_value=mock_redis))
            
            await cache_service.connect()
            
            assert cache_service.redis_client == mock_redis
            mock_redis.ping.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_connect_failure(self):
        """Test cache connection failure."""
        cache_service = CacheService()
        
        # Mock Redis to raise exception
        mock_redis = AsyncMock()
        mock_redis.ping.side_effect = Exception("Connection failed")
        
        with pytest.MonkeyPatch().context() as m:
            m.setattr('redis.asyncio.from_url', Mock(return_value=mock_redis))
            
            await cache_service.connect()
            
            assert cache_service.redis_client is None
    
    @pytest.mark.asyncio
    async def test_disconnect(self):
        """Test cache disconnection."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        cache_service.redis_client = mock_redis
        
        await cache_service.disconnect()
        
        mock_redis.close.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_success(self):
        """Test successful cache get."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        test_data = {"key": "value", "number": 123}
        mock_redis.get.return_value = json.dumps(test_data)
        cache_service.redis_client = mock_redis
        
        result = await cache_service.get("test_key")
        
        assert result == test_data
        mock_redis.get.assert_called_once_with("test_key")
    
    @pytest.mark.asyncio
    async def test_get_not_found(self):
        """Test cache get when key not found."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        mock_redis.get.return_value = None
        cache_service.redis_client = mock_redis
        
        result = await cache_service.get("nonexistent_key")
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_get_no_client(self):
        """Test cache get when no Redis client."""
        cache_service = CacheService()
        cache_service.redis_client = None
        
        result = await cache_service.get("test_key")
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_get_error(self):
        """Test cache get with Redis error."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        mock_redis.get.side_effect = Exception("Redis error")
        cache_service.redis_client = mock_redis
        
        result = await cache_service.get("test_key")
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_set_success(self):
        """Test successful cache set."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        mock_redis.set.return_value = True
        cache_service.redis_client = mock_redis
        
        test_data = {"key": "value"}
        result = await cache_service.set("test_key", test_data)
        
        assert result is True
        mock_redis.set.assert_called_once_with("test_key", json.dumps(test_data, default=str))
    
    @pytest.mark.asyncio
    async def test_set_with_ttl(self):
        """Test cache set with TTL."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        cache_service.redis_client = mock_redis
        
        test_data = {"key": "value"}
        await cache_service.set("test_key", test_data, ttl=300)
        
        mock_redis.setex.assert_called_once_with("test_key", 300, json.dumps(test_data, default=str))
    
    @pytest.mark.asyncio
    async def test_set_no_client(self):
        """Test cache set when no Redis client."""
        cache_service = CacheService()
        cache_service.redis_client = None
        
        result = await cache_service.set("test_key", {"data": "test"})
        
        assert result is False
    
    @pytest.mark.asyncio
    async def test_set_error(self):
        """Test cache set with Redis error."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        mock_redis.set.side_effect = Exception("Redis error")
        cache_service.redis_client = mock_redis
        
        result = await cache_service.set("test_key", {"data": "test"})
        
        assert result is False
    
    @pytest.mark.asyncio
    async def test_delete_success(self):
        """Test successful cache delete."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        mock_redis.delete.return_value = 1  # Key was deleted
        cache_service.redis_client = mock_redis
        
        result = await cache_service.delete("test_key")
        
        assert result is True
        mock_redis.delete.assert_called_once_with("test_key")
    
    @pytest.mark.asyncio
    async def test_delete_not_found(self):
        """Test cache delete when key not found."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        mock_redis.delete.return_value = 0  # Key was not found
        cache_service.redis_client = mock_redis
        
        result = await cache_service.delete("nonexistent_key")
        
        assert result is False
    
    @pytest.mark.asyncio
    async def test_exists_true(self):
        """Test cache exists when key exists."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        mock_redis.exists.return_value = 1
        cache_service.redis_client = mock_redis
        
        result = await cache_service.exists("test_key")
        
        assert result is True
    
    @pytest.mark.asyncio
    async def test_exists_false(self):
        """Test cache exists when key doesn't exist."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        mock_redis.exists.return_value = 0
        cache_service.redis_client = mock_redis
        
        result = await cache_service.exists("test_key")
        
        assert result is False
    
    @pytest.mark.asyncio
    async def test_increment_success(self):
        """Test successful cache increment."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        mock_redis.incr.return_value = 5
        cache_service.redis_client = mock_redis
        
        result = await cache_service.increment("counter_key")
        
        assert result == 5
        mock_redis.incr.assert_called_once_with("counter_key", 1)
    
    @pytest.mark.asyncio
    async def test_increment_with_amount(self):
        """Test cache increment with custom amount."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        mock_redis.incr.return_value = 10
        cache_service.redis_client = mock_redis
        
        result = await cache_service.increment("counter_key", 5)
        
        assert result == 10
        mock_redis.incr.assert_called_once_with("counter_key", 5)
    
    @pytest.mark.asyncio
    async def test_expire_success(self):
        """Test successful cache expire."""
        cache_service = CacheService()
        mock_redis = AsyncMock()
        mock_redis.expire.return_value = True
        cache_service.redis_client = mock_redis
        
        result = await cache_service.expire("test_key", 300)
        
        assert result is True
        mock_redis.expire.assert_called_once_with("test_key", 300)


class TestCacheHelperFunctions:
    
    def test_get_cache_key(self):
        """Test cache key generation."""
        key = get_cache_key("prefix", "arg1", "arg2", 123)
        assert key == "prefix:arg1_arg2_123"
        
        key = get_cache_key("simple")
        assert key == "simple:"
        
        key = get_cache_key("test", "single")
        assert key == "test:single"
    
    @pytest.mark.asyncio
    async def test_cached_agent_card(self, mock_cache):
        """Test cached agent card retrieval."""
        test_card = {"name": "Test Agent", "version": "1.0.0"}
        mock_cache.get.return_value = test_card
        
        result = await cached_agent_card("test.example.com")
        
        assert result == test_card
        mock_cache.get.assert_called_once_with("agent_card:test.example.com")
    
    @pytest.mark.asyncio
    async def test_cached_agent_card_not_found(self, mock_cache):
        """Test cached agent card when not found."""
        mock_cache.get.return_value = None
        
        result = await cached_agent_card("test.example.com")
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_cache_agent_card(self, mock_cache):
        """Test caching agent card."""
        test_card = {"name": "Test Agent", "version": "1.0.0"}
        mock_cache.set.return_value = True
        
        result = await cache_agent_card("test.example.com", test_card)
        
        assert result is True
        # Note: The actual TTL value is imported from settings, 
        # so we just verify set was called with the right key and data
        mock_cache.set.assert_called_once()
        call_args = mock_cache.set.call_args
        assert call_args[0][0] == "agent_card:test.example.com"
        assert call_args[0][1] == test_card