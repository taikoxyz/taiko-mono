import pytest
from unittest.mock import Mock, AsyncMock, patch
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from app.auth import (
    verify_signature_auth,
    verify_eip712_auth,
    apply_rate_limit,
    extract_client_ip,
    RateLimiter,
    AuthenticationError,
    AuthorizationError
)


class TestAuth:
    
    @pytest.mark.asyncio
    async def test_verify_signature_auth_success(self, mock_cache, mock_web3):
        """Test successful signature authentication."""
        credentials = HTTPAuthorizationCredentials(
            scheme="Bearer",
            credentials="test-message-to-sign"
        )
        
        agent_address = "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        signature = "0x1a2b3c4d5e6f7890abcdef..."
        
        # Mock cache to return False for replay check
        mock_cache.exists.return_value = False
        mock_cache.set.return_value = True
        
        result = await verify_signature_auth(
            authorization=credentials,
            agent_address=agent_address,
            signature=signature
        )
        
        assert result["agent_address"] == agent_address
        assert result["parsed_address"] == "0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        assert result["chain_id"] == 167000
        assert result["message"] == "test-message-to-sign"
        assert result["signature"] == signature
        assert "authenticated_at" in result
    
    @pytest.mark.asyncio
    async def test_verify_signature_auth_missing_authorization(self):
        """Test authentication failure with missing authorization."""
        with pytest.raises(AuthenticationError) as exc:
            await verify_signature_auth(
                authorization=None,
                agent_address="eip155:167000:0x123...",
                signature="0x456..."
            )
        assert "Missing authorization header" in str(exc.value)
    
    @pytest.mark.asyncio
    async def test_verify_signature_auth_missing_agent_address(self):
        """Test authentication failure with missing agent address."""
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="test")
        
        with pytest.raises(AuthenticationError) as exc:
            await verify_signature_auth(
                authorization=credentials,
                agent_address=None,
                signature="0x456..."
            )
        assert "Missing Agent-Address header" in str(exc.value)
    
    @pytest.mark.asyncio
    async def test_verify_signature_auth_invalid_signature(self, mock_cache, mock_web3):
        """Test authentication failure with invalid signature."""
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="test")
        
        # Mock Web3 service to return False for signature verification
        mock_web3.verify_signature.return_value = False
        
        with pytest.raises(AuthenticationError) as exc:
            await verify_signature_auth(
                authorization=credentials,
                agent_address="eip155:167000:0x123...",
                signature="0x456..."
            )
        assert "Invalid signature" in str(exc.value)
    
    @pytest.mark.asyncio
    async def test_verify_signature_auth_replay_attack(self, mock_cache, mock_web3):
        """Test authentication failure with replay attack."""
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="test")
        
        # Mock cache to return True for replay check (signature already used)
        mock_cache.exists.return_value = True
        
        with pytest.raises(AuthenticationError) as exc:
            await verify_signature_auth(
                authorization=credentials,
                agent_address="eip155:167000:0x123...",
                signature="0x456..."
            )
        assert "replay attack prevention" in str(exc.value)
    
    @pytest.mark.asyncio
    async def test_verify_eip712_auth_success(self, mock_cache, mock_web3):
        """Test successful EIP-712 authentication."""
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="test")
        structured_data = {
            "domain": {"name": "Test", "version": "1"},
            "primaryType": "TestMessage",
            "message": {"data": "test"}
        }
        
        mock_cache.exists.return_value = False
        mock_cache.set.return_value = True
        
        result = await verify_eip712_auth(
            structured_data=structured_data,
            authorization=credentials,
            agent_address="eip155:167000:0x123...",
            signature="0x456..."
        )
        
        assert result["agent_address"] == "eip155:167000:0x123..."
        assert result["structured_data"] == structured_data
        assert "authenticated_at" in result
    
    @pytest.mark.asyncio
    async def test_verify_eip712_auth_invalid_signature(self, mock_cache, mock_web3):
        """Test EIP-712 authentication failure with invalid signature."""
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="test")
        structured_data = {"test": "data"}
        
        # Mock Web3 service to return False for EIP-712 signature verification
        mock_web3.verify_eip712_signature.return_value = False
        
        with pytest.raises(AuthenticationError) as exc:
            await verify_eip712_auth(
                structured_data=structured_data,
                authorization=credentials,
                agent_address="eip155:167000:0x123...",
                signature="0x456..."
            )
        assert "Invalid EIP-712 signature" in str(exc.value)


class TestRateLimiter:
    
    def test_init(self):
        """Test RateLimiter initialization."""
        limiter = RateLimiter()
        assert limiter.window_size == 60
    
    @pytest.mark.asyncio
    async def test_check_rate_limit_success(self, mock_cache):
        """Test successful rate limit check."""
        limiter = RateLimiter()
        
        # Mock Redis operations
        mock_cache.redis_client = AsyncMock()
        mock_cache.redis_client.zremrangebyscore = AsyncMock()
        mock_cache.redis_client.zcard = AsyncMock(return_value=5)  # Under limit
        mock_cache.redis_client.zadd = AsyncMock()
        mock_cache.redis_client.expire = AsyncMock()
        
        result = await limiter.check_rate_limit("test_key", 10)
        assert result is True
    
    @pytest.mark.asyncio
    async def test_check_rate_limit_exceeded(self, mock_cache):
        """Test rate limit exceeded."""
        limiter = RateLimiter()
        
        # Mock Redis operations
        mock_cache.redis_client = AsyncMock()
        mock_cache.redis_client.zremrangebyscore = AsyncMock()
        mock_cache.redis_client.zcard = AsyncMock(return_value=15)  # Over limit
        
        result = await limiter.check_rate_limit("test_key", 10)
        assert result is False
    
    @pytest.mark.asyncio
    async def test_check_rate_limit_redis_error(self, mock_cache):
        """Test rate limit check with Redis error."""
        limiter = RateLimiter()
        
        # Mock Redis to raise exception
        mock_cache.redis_client = AsyncMock()
        mock_cache.redis_client.zremrangebyscore.side_effect = Exception("Redis error")
        
        # Should return True on Redis error (fail open)
        result = await limiter.check_rate_limit("test_key", 10)
        assert result is True
    
    @pytest.mark.asyncio
    async def test_get_rate_limit_key(self):
        """Test rate limit key generation."""
        limiter = RateLimiter()
        
        # With agent address
        key1 = await limiter.get_rate_limit_key(
            "192.168.1.1", 
            "eip155:167000:0x123...", 
            "feedback"
        )
        assert key1 == "eip155:167000:0x123...:feedback"
        
        # Without agent address
        key2 = await limiter.get_rate_limit_key("192.168.1.1")
        assert key2 == "192.168.1.1:api"
        
        # With endpoint only
        key3 = await limiter.get_rate_limit_key("192.168.1.1", endpoint="health")
        assert key3 == "192.168.1.1:health"


class TestApplyRateLimit:
    
    @pytest.mark.asyncio
    async def test_apply_rate_limit_success(self, mock_cache, monkeypatch):
        """Test successful rate limit application."""
        # Disable rate limiting
        monkeypatch.setenv("RATE_LIMIT_ENABLED", "false")
        
        # Should not raise exception when rate limiting is disabled
        await apply_rate_limit("192.168.1.1")
    
    @pytest.mark.asyncio
    async def test_apply_rate_limit_authenticated_higher_limit(self, mock_cache):
        """Test authenticated users get higher rate limits."""
        # Mock rate limiter to succeed
        with patch('app.auth.rate_limiter.check_rate_limit', return_value=True):
            await apply_rate_limit(
                "192.168.1.1", 
                "eip155:167000:0x123...", 
                "test",
                is_authenticated=True
            )
        # Should not raise exception
    
    @pytest.mark.asyncio 
    async def test_apply_rate_limit_exceeded(self, mock_cache):
        """Test rate limit exceeded raises HTTPException."""
        # Mock rate limiter to fail
        with patch('app.auth.rate_limiter.check_rate_limit', return_value=False):
            with pytest.raises(HTTPException) as exc:
                await apply_rate_limit("192.168.1.1")
            
            assert exc.value.status_code == 429
            assert "Rate limit exceeded" in str(exc.value.detail)


class TestExtractClientIP:
    
    def test_extract_client_ip_forwarded_for(self):
        """Test extracting IP from X-Forwarded-For header."""
        mock_request = Mock()
        mock_request.headers = {"X-Forwarded-For": "203.0.113.1, 192.168.1.1"}
        mock_request.client.host = "127.0.0.1"
        
        ip = extract_client_ip(mock_request)
        assert ip == "203.0.113.1"
    
    def test_extract_client_ip_real_ip(self):
        """Test extracting IP from X-Real-IP header."""
        mock_request = Mock()
        mock_request.headers = {"X-Real-IP": "203.0.113.2"}
        mock_request.client.host = "127.0.0.1"
        
        ip = extract_client_ip(mock_request)
        assert ip == "203.0.113.2"
    
    def test_extract_client_ip_direct(self):
        """Test extracting IP directly from client."""
        mock_request = Mock()
        mock_request.headers = {}
        mock_request.client.host = "203.0.113.3"
        
        ip = extract_client_ip(mock_request)
        assert ip == "203.0.113.3"
    
    def test_extract_client_ip_no_client(self):
        """Test extracting IP when no client info."""
        mock_request = Mock()
        mock_request.headers = {}
        mock_request.client = None
        
        ip = extract_client_ip(mock_request)
        assert ip == "unknown"