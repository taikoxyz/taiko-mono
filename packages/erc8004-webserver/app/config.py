from pydantic_settings import BaseSettings
from typing import List, Optional
import os


class Settings(BaseSettings):
    # Server Configuration
    server_host: str = "0.0.0.0"
    server_port: int = 8000
    agent_domain: str = "agent.example.com"
    environment: str = "production"
    
    # Database Configuration
    database_url: str = "postgresql+asyncpg://user:pass@postgres:5432/agent_db"
    database_pool_size: int = 20
    database_max_overflow: int = 40
    
    # Redis Configuration
    redis_url: str = "redis://redis:6379"
    redis_pool_size: int = 10
    
    # Blockchain Configuration
    web3_provider: str = "https://rpc.taiko.xyz"
    chain_id: int = 167000
    contract_address: Optional[str] = None
    
    # Security
    secret_key: str = "your-secret-key-change-in-production"
    cors_origins: List[str] = ["https://app.example.com", "https://api.example.com"]
    rate_limit_enabled: bool = True
    
    # Storage
    data_path: str = "/data/agent_data"
    ipfs_gateway: str = "https://ipfs.io/ipfs/"
    max_upload_size: int = 10485760  # 10MB
    
    # Monitoring
    metrics_enabled: bool = True
    log_level: str = "INFO"
    
    # Cache TTL (in seconds)
    agent_card_cache_ttl: int = 300  # 5 minutes
    feedback_list_cache_ttl: int = 60  # 1 minute
    reputation_cache_ttl: int = 30  # 30 seconds
    
    # Rate Limiting
    rate_limit_public: str = "100/minute"
    rate_limit_authenticated: str = "1000/minute"
    
    # Pagination
    default_page_size: int = 20
    max_page_size: int = 100
    
    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()