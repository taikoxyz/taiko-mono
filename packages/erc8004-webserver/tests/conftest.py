import pytest
import asyncio
import os
from typing import AsyncGenerator, Generator
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import StaticPool
import redis.asyncio as redis
from unittest.mock import AsyncMock, MagicMock

# Set test environment before importing app modules
os.environ['ENVIRONMENT'] = 'test'
os.environ['DATABASE_URL'] = 'sqlite+aiosqlite:///./test.db'

from app.main import app
from app.database import get_session, Base
from app.cache import cache
from app.config import settings
from app.web3_service import web3_service


# Test database configuration
TEST_DATABASE_URL = "sqlite+aiosqlite:///./test.db"

# Test engine with in-memory SQLite
test_engine = create_async_engine(
    TEST_DATABASE_URL,
    poolclass=StaticPool,
    connect_args={"check_same_thread": False},
    echo=False
)

# Test session factory
test_session_maker = async_sessionmaker(
    test_engine,
    class_=AsyncSession,
    expire_on_commit=False
)


@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()




@pytest.fixture(scope="function")
def override_get_db():
    """Override the database dependency."""
    import asyncio
    
    # Get or create event loop for synchronous fixture
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    
    # Create tables synchronously
    async def setup():
        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        return await test_session_maker().__aenter__()
    
    session = loop.run_until_complete(setup())
    
    # Set up dependency override
    async def _override_get_db():
        yield session
    
    app.dependency_overrides[get_session] = _override_get_db
    yield session
    app.dependency_overrides.clear()
    
    # Cleanup
    async def cleanup():
        await session.close()
        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.drop_all)
    
    loop.run_until_complete(cleanup())


@pytest.fixture
async def mock_cache():
    """Mock Redis cache for testing."""
    mock_redis = AsyncMock()
    mock_redis.get.return_value = None
    mock_redis.set.return_value = True
    mock_redis.delete.return_value = True
    mock_redis.exists.return_value = False
    mock_redis.ping.return_value = True
    
    original_client = cache.redis_client
    cache.redis_client = mock_redis
    
    yield mock_redis
    
    cache.redis_client = original_client


@pytest.fixture
def mock_web3():
    """Mock Web3 service for testing."""
    original_w3 = web3_service.w3
    original_verify_signature = web3_service.verify_signature
    original_verify_eip712_signature = web3_service.verify_eip712_signature
    original_parse_caip10_address = web3_service.parse_caip10_address
    
    # Mock Web3 instance
    mock_w3 = MagicMock()
    mock_w3.is_connected.return_value = True
    web3_service.w3 = mock_w3
    
    # Mock signature verification (default to True)
    web3_service.verify_signature = MagicMock(return_value=True)
    web3_service.verify_eip712_signature = MagicMock(return_value=True)
    web3_service.parse_caip10_address = MagicMock(
        return_value=("0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8", 167000)
    )
    
    yield web3_service
    
    # Restore original methods
    web3_service.w3 = original_w3
    web3_service.verify_signature = original_verify_signature
    web3_service.verify_eip712_signature = original_verify_eip712_signature
    web3_service.parse_caip10_address = original_parse_caip10_address


@pytest.fixture
def client(override_get_db, mock_cache, mock_web3):
    """Create a test client."""
    return TestClient(app)

@pytest.fixture
async def async_client(override_get_db, mock_cache, mock_web3):
    """Create an async test client."""
    from httpx import AsyncClient
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def sample_agent_address():
    """Sample agent address in CAIP-10 format."""
    return "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"


@pytest.fixture
def sample_signature():
    """Sample Ethereum signature."""
    return "0x1a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef1234567890123456789abcdef1234567890abcdef1234567890abcdef1234567890abcdef12"


@pytest.fixture
def sample_agent_card():
    """Sample agent card data."""
    return {
        "name": "Test AI Agent",
        "description": "A test agent for automated testing",
        "version": "1.0.0",
        "skills": [
            {
                "skillId": "test-skill",
                "description": "A test skill",
                "inputs": {"param1": "string"},
                "outputs": {"result": "string"}
            }
        ],
        "registrations": [
            {
                "agentId": 12345,
                "agentAddress": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
                "signature": "0x1a2b3c4d..."
            }
        ],
        "trustModels": ["reputation", "stake"],
        "FeedbackDataURI": "https://test.example.com/api/v1/feedback",
        "ValidationRequestsURI": "https://test.example.com/api/v1/validations/requests",
        "ValidationResponsesURI": "https://test.example.com/api/v1/validations/responses"
    }


@pytest.fixture
def sample_feedback_data():
    """Sample feedback data."""
    return {
        "FeedbackAuthID": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
        "AgentSkillId": "test-skill",
        "TaskId": "task-123",
        "contextId": "context-456", 
        "Rating": 95,
        "ProofOfPayment": {
            "txHash": "0xabc123def456...",
            "amount": "100",
            "token": "USDC"
        },
        "Data": {
            "completionTime": 30,
            "accuracy": 0.98
        }
    }


@pytest.fixture
def auth_headers(sample_agent_address, sample_signature):
    """Authentication headers for requests."""
    return {
        "Authorization": "Bearer test-message",
        "Agent-Address": sample_agent_address,
        "Signature": sample_signature
    }


@pytest.fixture(autouse=True)
def setup_test_environment(monkeypatch):
    """Setup test environment variables."""
    monkeypatch.setenv("ENVIRONMENT", "testing")
    monkeypatch.setenv("SECRET_KEY", "test-secret-key")
    monkeypatch.setenv("DATABASE_URL", TEST_DATABASE_URL)
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    monkeypatch.setenv("RATE_LIMIT_ENABLED", "false")  # Disable rate limiting in tests
    monkeypatch.setenv("METRICS_ENABLED", "false")  # Disable metrics in tests