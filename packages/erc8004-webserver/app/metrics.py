from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from fastapi import Response
from typing import Dict, Any
import time
import psutil
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from .models import Agent, Feedback, ValidationRequest, ValidationResponse
from .config import settings

# Prometheus metrics
request_count = Counter(
    'erc8004_requests_total',
    'Total number of HTTP requests',
    ['method', 'endpoint', 'status_code']
)

request_duration = Histogram(
    'erc8004_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

active_connections = Gauge(
    'erc8004_active_connections',
    'Number of active connections'
)

database_connections = Gauge(
    'erc8004_database_connections',
    'Number of database connections',
    ['state']
)

cache_operations = Counter(
    'erc8004_cache_operations_total',
    'Total cache operations',
    ['operation', 'result']
)

agent_count = Gauge(
    'erc8004_agents_total',
    'Total number of registered agents'
)

feedback_count = Gauge(
    'erc8004_feedback_total',
    'Total number of feedback records'
)

validation_request_count = Gauge(
    'erc8004_validation_requests_total',
    'Total number of validation requests'
)

validation_response_count = Gauge(
    'erc8004_validation_responses_total',
    'Total number of validation responses'
)

average_reputation = Gauge(
    'erc8004_average_reputation_score',
    'Average reputation score across all agents'
)

system_memory_usage = Gauge(
    'erc8004_system_memory_usage_bytes',
    'System memory usage in bytes',
    ['type']
)

system_cpu_usage = Gauge(
    'erc8004_system_cpu_usage_percent',
    'System CPU usage percentage'
)

web3_connection_status = Gauge(
    'erc8004_web3_connection_status',
    'Web3 connection status (1=connected, 0=disconnected)'
)

redis_connection_status = Gauge(
    'erc8004_redis_connection_status',
    'Redis connection status (1=connected, 0=disconnected)'
)

database_connection_status = Gauge(
    'erc8004_database_connection_status',
    'Database connection status (1=connected, 0=disconnected)'
)

# Custom metrics collector
class MetricsCollector:
    def __init__(self):
        self.start_time = time.time()
    
    def record_request(self, method: str, endpoint: str, status_code: int, duration: float):
        """Record HTTP request metrics"""
        request_count.labels(method=method, endpoint=endpoint, status_code=status_code).inc()
        request_duration.labels(method=method, endpoint=endpoint).observe(duration)
    
    def record_cache_operation(self, operation: str, result: str):
        """Record cache operation metrics"""
        cache_operations.labels(operation=operation, result=result).inc()
    
    async def update_database_metrics(self, db: AsyncSession):
        """Update database-related metrics"""
        try:
            # Count agents
            agent_result = await db.execute(select(func.count(Agent.agent_id)))
            agent_count.set(agent_result.scalar() or 0)
            
            # Count feedback
            feedback_result = await db.execute(select(func.count(Feedback.id)))
            feedback_count.set(feedback_result.scalar() or 0)
            
            # Count validation requests
            val_req_result = await db.execute(select(func.count(ValidationRequest.id)))
            validation_request_count.set(val_req_result.scalar() or 0)
            
            # Count validation responses
            val_resp_result = await db.execute(select(func.count(ValidationResponse.id)))
            validation_response_count.set(val_resp_result.scalar() or 0)
            
            # Calculate average reputation (simplified)
            rating_result = await db.execute(select(func.avg(Feedback.rating)))
            avg_rating = rating_result.scalar()
            if avg_rating:
                average_reputation.set(float(avg_rating))
            
            database_connection_status.set(1)
            
        except Exception as e:
            database_connection_status.set(0)
    
    def update_system_metrics(self):
        """Update system resource metrics"""
        try:
            # Memory usage
            memory = psutil.virtual_memory()
            system_memory_usage.labels(type="used").set(memory.used)
            system_memory_usage.labels(type="available").set(memory.available)
            system_memory_usage.labels(type="total").set(memory.total)
            
            # CPU usage
            cpu_percent = psutil.cpu_percent(interval=1)
            system_cpu_usage.set(cpu_percent)
            
        except Exception as e:
            pass
    
    def update_connection_status(self, web3_connected: bool, redis_connected: bool):
        """Update connection status metrics"""
        web3_connection_status.set(1 if web3_connected else 0)
        redis_connection_status.set(1 if redis_connected else 0)
    
    def get_uptime(self) -> float:
        """Get application uptime in seconds"""
        return time.time() - self.start_time


# Global metrics collector instance
metrics_collector = MetricsCollector()


async def get_application_metrics(db: AsyncSession) -> Dict[str, Any]:
    """Get comprehensive application metrics for JSON response"""
    
    # Update database metrics
    await metrics_collector.update_database_metrics(db)
    
    # Update system metrics
    metrics_collector.update_system_metrics()
    
    # Get current values
    agent_result = await db.execute(select(func.count(Agent.agent_id)))
    total_agents = agent_result.scalar() or 0
    
    feedback_result = await db.execute(select(func.count(Feedback.id)))
    total_feedback = feedback_result.scalar() or 0
    
    val_req_result = await db.execute(select(func.count(ValidationRequest.id)))
    total_validation_requests = val_req_result.scalar() or 0
    
    val_resp_result = await db.execute(select(func.count(ValidationResponse.id)))
    total_validation_responses = val_resp_result.scalar() or 0
    
    rating_result = await db.execute(select(func.avg(Feedback.rating)))
    avg_rating = rating_result.scalar() or 0
    
    return {
        "total_agents": total_agents,
        "total_feedback": total_feedback,
        "total_validation_requests": total_validation_requests,
        "total_validation_responses": total_validation_responses,
        "average_reputation": float(avg_rating),
        "uptime_seconds": metrics_collector.get_uptime(),
        "timestamp": datetime.utcnow().isoformat(),
        "system": {
            "memory": {
                "used": psutil.virtual_memory().used,
                "available": psutil.virtual_memory().available,
                "total": psutil.virtual_memory().total,
                "percent": psutil.virtual_memory().percent
            },
            "cpu_percent": psutil.cpu_percent(),
            "disk": {
                "used": psutil.disk_usage('/').used,
                "free": psutil.disk_usage('/').free,
                "total": psutil.disk_usage('/').total,
                "percent": psutil.disk_usage('/').percent
            }
        }
    }


async def get_prometheus_metrics() -> Response:
    """Get Prometheus metrics endpoint response"""
    if not settings.metrics_enabled:
        return Response(
            content="Metrics disabled",
            media_type="text/plain",
            status_code=404
        )
    
    # Update system metrics
    metrics_collector.update_system_metrics()
    
    # Generate Prometheus format
    metrics_output = generate_latest()
    
    return Response(
        content=metrics_output,
        media_type=CONTENT_TYPE_LATEST
    )