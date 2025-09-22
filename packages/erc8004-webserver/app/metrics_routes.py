from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from .database import get_session
from .metrics import get_application_metrics, get_prometheus_metrics, metrics_collector
from .auth import apply_rate_limit, extract_client_ip
from .schemas import MetricsSchema

router = APIRouter()

@router.get("/metrics")
async def prometheus_metrics():
    """Prometheus metrics endpoint"""
    return await get_prometheus_metrics()

@router.get("/metrics/json", response_model=MetricsSchema)
async def json_metrics(
    request: Request,
    db: AsyncSession = Depends(get_session)
):
    """JSON metrics endpoint for application monitoring"""
    
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, None, "metrics", False)
    
    return await get_application_metrics(db)