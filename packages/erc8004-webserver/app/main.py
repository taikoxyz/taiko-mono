from fastapi import FastAPI, Depends, HTTPException, Request, Header, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_
from typing import Optional, List, Dict, Any
import structlog
import time
import uuid
from datetime import datetime, timezone, timedelta
import math

from .config import settings
from .database import get_session, init_database, close_database
from .cache import cache
from .models import Agent, Feedback, ValidationRequest, ValidationResponse
from .schemas import (
    AgentCardSchema, AgentCreateSchema, AgentResponseSchema,
    FeedbackCreateSchema, FeedbackResponseSchema,
    ValidationRequestCreateSchema, ValidationRequestResponseSchema,
    ValidationResponseCreateSchema, ValidationResponseResponseSchema,
    ValidationRequestListSchema, ReputationScoreSchema,
    HealthCheckSchema, ErrorResponseSchema, PaginatedResponseSchema,
    SignatureVerificationSchema
)
from .auth import (
    verify_signature_auth, verify_eip712_auth, apply_rate_limit, 
    extract_client_ip, AuthenticationError, AuthorizationError
)
from .web3_service import web3_service
from .metrics import get_application_metrics, get_prometheus_metrics

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Application startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting ERC-8004 Off-Chain Storage Server")
    await cache.connect()
    await init_database()
    yield
    # Shutdown
    logger.info("Shutting down ERC-8004 Off-Chain Storage Server")
    await cache.disconnect()
    await close_database()

# Create FastAPI app
app = FastAPI(
    title="ERC-8004 Off-Chain Storage Server",
    description="Production-ready ERC-8004 compliant off-chain storage server for Trustless Agents",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/api/docs" if settings.environment != "production" else None,
    redoc_url="/api/redoc" if settings.environment != "production" else None
)

# Add middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

if settings.environment == "production":
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=[settings.agent_domain, "localhost"]
    )

# Request ID and logging middleware
@app.middleware("http")
async def add_request_id_and_logging(request: Request, call_next):
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    
    start_time = time.time()
    client_ip = extract_client_ip(request)
    
    logger.info(
        "Request started",
        request_id=request_id,
        method=request.method,
        url=str(request.url),
        client_ip=client_ip
    )
    
    response = await call_next(request)
    
    process_time = time.time() - start_time
    logger.info(
        "Request completed",
        request_id=request_id,
        method=request.method,
        url=str(request.url),
        status_code=response.status_code,
        process_time=process_time,
        client_ip=client_ip
    )
    
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Process-Time"] = str(process_time)
    
    return response

# Exception handlers
@app.exception_handler(AuthenticationError)
async def authentication_exception_handler(request: Request, exc: AuthenticationError):
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponseSchema(
            error="AuthenticationError",
            message=exc.detail,
            timestamp=datetime.now(timezone.utc),
            request_id=getattr(request.state, 'request_id', None)
        ).model_dump(mode='json')
    )

@app.exception_handler(AuthorizationError)
async def authorization_exception_handler(request: Request, exc: AuthorizationError):
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponseSchema(
            error="AuthorizationError",
            message=exc.detail,
            timestamp=datetime.now(timezone.utc),
            request_id=getattr(request.state, 'request_id', None)
        ).model_dump(mode='json')
    )

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponseSchema(
            error="HTTPException",
            message=exc.detail,
            timestamp=datetime.now(timezone.utc),
            request_id=getattr(request.state, 'request_id', None)
        ).model_dump(mode='json')
    )

# Health check endpoint
@app.get("/health", response_model=HealthCheckSchema)
async def health_check(db: AsyncSession = Depends(get_session)):
    """Kubernetes health check endpoint"""
    services = {}
    
    # Check database
    try:
        await db.execute(select(1))
        services["database"] = "healthy"
    except Exception:
        services["database"] = "unhealthy"
    
    # Check Redis
    try:
        await cache.redis_client.ping() if cache.redis_client else None
        services["redis"] = "healthy"
    except Exception:
        services["redis"] = "unhealthy"
    
    # Check Web3 connection
    try:
        web3_service.w3.is_connected()
        services["web3"] = "healthy"
    except Exception:
        services["web3"] = "unhealthy"
    
    status = "healthy" if all(s == "healthy" for s in services.values()) else "unhealthy"
    
    return HealthCheckSchema(
        status=status,
        timestamp=datetime.utcnow(),
        services=services
    )

# RFC 8615 compliant AgentCard endpoint
@app.get("/.well-known/agent-card.json", response_model=AgentCardSchema)
async def get_agent_card(db: AsyncSession = Depends(get_session)):
    """RFC 8615 compliant AgentCard endpoint"""
    
    # Try cache first
    cached_card = await cache.get(f"agent_card:{settings.agent_domain}")
    if cached_card:
        return cached_card
    
    # Get agent from database
    result = await db.execute(
        select(Agent).where(
            and_(
                Agent.agent_domain == settings.agent_domain,
                Agent.is_active == True
            )
        )
    )
    agent = result.scalar_one_or_none()
    
    if not agent:
        raise HTTPException(status_code=404, detail="Agent card not found")
    
    agent_card = agent.agent_card.copy()
    
    # Ensure URIs are properly formatted
    base_url = f"https://{settings.agent_domain}"
    agent_card.update({
        "FeedbackDataURI": f"{base_url}/api/v1/feedback",
        "ValidationRequestsURI": f"{base_url}/api/v1/validations/requests", 
        "ValidationResponsesURI": f"{base_url}/api/v1/validations/responses"
    })
    
    # Cache the result
    await cache.set(f"agent_card:{settings.agent_domain}", agent_card, settings.agent_card_cache_ttl)
    
    return agent_card

# Agent registration endpoint
@app.post("/api/v1/agent/register", response_model=AgentResponseSchema)
async def register_agent(
    agent_data: AgentCreateSchema,
    request: Request,
    db: AsyncSession = Depends(get_session),
    agent_address: Optional[str] = Header(None, alias="Agent-Address"),
    signature: Optional[str] = Header(None, alias="Signature")
):
    """Register or update agent"""
    
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, agent_address, "register", bool(agent_address))
    
    # Create EIP-712 message for agent registration
    structured_data = web3_service.create_agent_registration_message(
        agent_data.agent_address,
        agent_data.agent_domain,
        agent_data.agent_card.model_dump()
    )
    
    # Verify signature
    auth_data = await verify_eip712_auth(
        structured_data,
        agent_address=agent_address,
        signature=signature
    )
    
    # Check if agent already exists
    result = await db.execute(
        select(Agent).where(Agent.agent_address == agent_data.agent_address)
    )
    existing_agent = result.scalar_one_or_none()
    
    if existing_agent:
        # Update existing agent
        existing_agent.agent_domain = agent_data.agent_domain
        existing_agent.agent_card = agent_data.agent_card.model_dump()
        existing_agent.signature = signature
        existing_agent.updated_at = datetime.now(timezone.utc)
        agent = existing_agent
    else:
        # Create new agent
        agent = Agent(
            agent_address=agent_data.agent_address,
            agent_domain=agent_data.agent_domain,
            agent_card=agent_data.agent_card.model_dump(),
            signature=signature
        )
        db.add(agent)
    
    await db.commit()
    await db.refresh(agent)
    
    # Invalidate cache
    await cache.delete(f"agent_card:{agent_data.agent_domain}")
    
    logger.info("Agent registered/updated", agent_address=agent_data.agent_address)
    
    return agent

# Feedback endpoints
@app.get("/api/v1/feedback", response_model=PaginatedResponseSchema)
async def list_feedback(
    request: Request,
    db: AsyncSession = Depends(get_session),
    page: int = Query(1, ge=1),
    page_size: int = Query(settings.default_page_size, ge=1, le=settings.max_page_size),
    agent_server_id: Optional[int] = Query(None),
    agent_skill_id: Optional[str] = Query(None),
    min_rating: Optional[int] = Query(None, ge=0, le=100),
    max_rating: Optional[int] = Query(None, ge=0, le=100)
):
    """List all feedback with pagination and filtering"""
    
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, None, "feedback_list", False)
    
    # Try cache first
    cache_key = f"feedback_list:{page}:{page_size}:{agent_server_id}:{agent_skill_id}:{min_rating}:{max_rating}"
    cached_result = await cache.get(cache_key)
    if cached_result:
        return cached_result
    
    # Build query
    query = select(Feedback)
    conditions = []
    
    if agent_server_id:
        conditions.append(Feedback.agent_server_id == agent_server_id)
    if agent_skill_id:
        conditions.append(Feedback.agent_skill_id == agent_skill_id)
    if min_rating is not None:
        conditions.append(Feedback.rating >= min_rating)
    if max_rating is not None:
        conditions.append(Feedback.rating <= max_rating)
    
    if conditions:
        query = query.where(and_(*conditions))
    
    # Get total count
    count_query = select(func.count()).select_from(Feedback)
    if conditions:
        count_query = count_query.where(and_(*conditions))
    
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # Apply pagination
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size).order_by(Feedback.created_at.desc())
    
    result = await db.execute(query)
    feedback_list = result.scalars().all()
    
    # Convert to response format
    items = [
        FeedbackResponseSchema(
            id=f.id,
            FeedbackAuthID=f.feedback_auth_id,
            AgentSkillId=f.agent_skill_id,
            TaskId=f.task_id,
            contextId=f.context_id,
            Rating=f.rating,
            ProofOfPayment=f.proof_of_payment,
            Data=f.data,
            signature=f.signature,
            created_at=f.created_at,
            ipfs_hash=f.ipfs_hash
        )
        for f in feedback_list
    ]
    
    total_pages = math.ceil(total / page_size)
    
    response_data = PaginatedResponseSchema(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages
    )
    
    # Cache the result
    await cache.set(cache_key, response_data.model_dump(), settings.feedback_list_cache_ttl)
    
    return response_data

@app.post("/api/v1/feedback", response_model=FeedbackResponseSchema)
async def submit_feedback(
    feedback_data: FeedbackCreateSchema,
    request: Request,
    db: AsyncSession = Depends(get_session),
    agent_address: Optional[str] = Header(None, alias="Agent-Address"),
    signature: Optional[str] = Header(None, alias="Signature")
):
    """Submit new feedback (requires authentication)"""
    
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, agent_address, "feedback_submit", True)
    
    # Create EIP-712 message for feedback
    structured_data = web3_service.create_feedback_message(
        feedback_data.FeedbackAuthID,
        feedback_data.AgentSkillId,
        feedback_data.TaskId,
        feedback_data.contextId,
        feedback_data.Rating,
        feedback_data.ProofOfPayment,
        feedback_data.Data
    )
    
    # Verify signature
    auth_data = await verify_eip712_auth(
        structured_data,
        agent_address=agent_address,
        signature=signature
    )
    
    # Find client and server agents
    client_result = await db.execute(
        select(Agent).where(Agent.agent_address == agent_address)
    )
    client_agent = client_result.scalar_one_or_none()
    
    server_result = await db.execute(
        select(Agent).where(Agent.agent_address == feedback_data.FeedbackAuthID)
    )
    server_agent = server_result.scalar_one_or_none()
    
    # Generate IPFS hash
    ipfs_hash = web3_service.generate_ipfs_hash({
        "feedback": feedback_data.model_dump(),
        "signature": signature,
        "timestamp": datetime.utcnow().isoformat()
    })
    
    # Create feedback record
    feedback = Feedback(
        feedback_auth_id=feedback_data.FeedbackAuthID,
        agent_client_id=client_agent.agent_id if client_agent else None,
        agent_server_id=server_agent.agent_id if server_agent else None,
        agent_skill_id=feedback_data.AgentSkillId,
        task_id=feedback_data.TaskId,
        context_id=feedback_data.contextId,
        rating=feedback_data.Rating,
        proof_of_payment=feedback_data.ProofOfPayment,
        data=feedback_data.Data,
        signature=signature,
        ipfs_hash=ipfs_hash
    )
    
    db.add(feedback)
    await db.commit()
    await db.refresh(feedback)
    
    # Invalidate related caches
    await cache.delete(f"feedback_list:*")
    if server_agent:
        await cache.delete(f"reputation:{server_agent.agent_address}")
    
    logger.info("Feedback submitted", feedback_id=feedback.id, client=agent_address)
    
    return FeedbackResponseSchema(
        id=feedback.id,
        FeedbackAuthID=feedback.feedback_auth_id,
        AgentSkillId=feedback.agent_skill_id,
        TaskId=feedback.task_id,
        contextId=feedback.context_id,
        Rating=feedback.rating,
        ProofOfPayment=feedback.proof_of_payment,
        Data=feedback.data,
        signature=feedback.signature,
        created_at=feedback.created_at,
        ipfs_hash=feedback.ipfs_hash
    )

@app.get("/api/v1/feedback/{feedback_auth_id}", response_model=FeedbackResponseSchema)
async def get_feedback(
    feedback_auth_id: str,
    request: Request,
    db: AsyncSession = Depends(get_session)
):
    """Get specific feedback by auth ID"""
    
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, None, "feedback_get", False)
    
    result = await db.execute(
        select(Feedback).where(Feedback.feedback_auth_id == feedback_auth_id)
    )
    feedback = result.scalar_one_or_none()
    
    if not feedback:
        raise HTTPException(status_code=404, detail="Feedback not found")
    
    return FeedbackResponseSchema(
        id=feedback.id,
        FeedbackAuthID=feedback.feedback_auth_id,
        AgentSkillId=feedback.agent_skill_id,
        TaskId=feedback.task_id,
        contextId=feedback.context_id,
        Rating=feedback.rating,
        ProofOfPayment=feedback.proof_of_payment,
        Data=feedback.data,
        signature=feedback.signature,
        created_at=feedback.created_at,
        ipfs_hash=feedback.ipfs_hash
    )

# Validation endpoints
@app.get("/api/v1/validations/requests", response_model=ValidationRequestListSchema)
async def list_validation_requests(
    request: Request,
    db: AsyncSession = Depends(get_session)
):
    """Returns DataHash -> DataURI mapping for validation requests"""
    
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, None, "validation_requests", False)
    
    # Get active validation requests (not expired)
    result = await db.execute(
        select(ValidationRequest).where(
            ValidationRequest.expires_at > datetime.now(timezone.utc)
        )
    )
    requests = result.scalars().all()
    
    # Create DataHash -> DataURI mapping
    request_mapping = {
        req.data_hash: req.data_uri
        for req in requests
    }
    
    return ValidationRequestListSchema(requests=request_mapping)

@app.post("/api/v1/validations/requests", response_model=ValidationRequestResponseSchema)
async def submit_validation_request(
    validation_data: ValidationRequestCreateSchema,
    request: Request,
    db: AsyncSession = Depends(get_session),
    agent_address: Optional[str] = Header(None, alias="Agent-Address"),
    signature: Optional[str] = Header(None, alias="Signature")
):
    """Submit validation request"""
    
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, agent_address, "validation_request_submit", True)
    
    # Simple signature verification for validation requests
    auth_data = await verify_signature_auth(
        agent_address=agent_address,
        signature=signature
    )
    
    # Find server agent
    server_result = await db.execute(
        select(Agent).where(Agent.agent_address == agent_address)
    )
    server_agent = server_result.scalar_one_or_none()
    
    if not server_agent:
        raise HTTPException(status_code=404, detail="Server agent not found")
    
    # Create validation request
    val_request = ValidationRequest(
        data_hash=validation_data.data_hash,
        agent_validator_id=validation_data.agent_validator_id,
        agent_server_id=server_agent.agent_id,
        data_uri=validation_data.data_uri,
        validation_data=validation_data.validation_data,
        expires_at=validation_data.expires_at
    )
    
    db.add(val_request)
    await db.commit()
    await db.refresh(val_request)
    
    logger.info("Validation request submitted", request_id=val_request.id)
    
    return val_request

@app.get("/api/v1/validations/responses", response_model=List[ValidationResponseResponseSchema])
async def list_validation_responses(
    request: Request,
    db: AsyncSession = Depends(get_session),
    data_hash: Optional[str] = Query(None)
):
    """Get validation responses"""
    
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, None, "validation_responses", False)
    
    query = select(ValidationResponse)
    if data_hash:
        query = query.where(ValidationResponse.data_hash == data_hash)
    
    result = await db.execute(query.order_by(ValidationResponse.created_at.desc()))
    responses = result.scalars().all()
    
    return [
        ValidationResponseResponseSchema(
            id=r.id,
            data_hash=r.data_hash,
            agent_validator_id=r.agent_validator_id,
            response=r.response,
            evidence=r.evidence,
            validator_signature=r.validator_signature,
            created_at=r.created_at,
            ipfs_hash=r.ipfs_hash
        )
        for r in responses
    ]

@app.post("/api/v1/validations/responses", response_model=ValidationResponseResponseSchema)
async def submit_validation_response(
    response_data: ValidationResponseCreateSchema,
    request: Request,
    db: AsyncSession = Depends(get_session),
    agent_address: Optional[str] = Header(None, alias="Agent-Address"),
    signature: Optional[str] = Header(None, alias="Signature")
):
    """Submit validation response (validators only)"""
    
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, agent_address, "validation_response_submit", True)
    
    # Create EIP-712 message for validation response
    structured_data = web3_service.create_validation_response_message(
        response_data.data_hash,
        response_data.response,
        response_data.evidence
    )
    
    # Verify signature
    auth_data = await verify_eip712_auth(
        structured_data,
        agent_address=agent_address,
        signature=signature
    )
    
    # Find validator agent
    validator_result = await db.execute(
        select(Agent).where(Agent.agent_address == agent_address)
    )
    validator_agent = validator_result.scalar_one_or_none()
    
    if not validator_agent:
        raise HTTPException(status_code=404, detail="Validator agent not found")
    
    # Check if validation request exists and is still valid
    req_result = await db.execute(
        select(ValidationRequest).where(
            and_(
                ValidationRequest.data_hash == response_data.data_hash,
                ValidationRequest.expires_at > datetime.now(timezone.utc)
            )
        )
    )
    validation_request = req_result.scalar_one_or_none()
    
    if not validation_request:
        raise HTTPException(status_code=404, detail="Validation request not found or expired")
    
    # Generate IPFS hash
    ipfs_hash = web3_service.generate_ipfs_hash({
        "validation_response": response_data.model_dump(),
        "signature": signature,
        "timestamp": datetime.utcnow().isoformat()
    })
    
    # Create validation response
    val_response = ValidationResponse(
        data_hash=response_data.data_hash,
        agent_validator_id=validator_agent.agent_id,
        response=response_data.response,
        evidence=response_data.evidence,
        validator_signature=signature,
        ipfs_hash=ipfs_hash
    )
    
    db.add(val_response)
    await db.commit()
    await db.refresh(val_response)
    
    logger.info("Validation response submitted", response_id=val_response.id)
    
    return ValidationResponseResponseSchema(
        id=val_response.id,
        data_hash=val_response.data_hash,
        agent_validator_id=val_response.agent_validator_id,
        response=val_response.response,
        evidence=val_response.evidence,
        validator_signature=val_response.validator_signature,
        created_at=val_response.created_at,
        ipfs_hash=val_response.ipfs_hash
    )

# Reputation endpoint
@app.get("/api/v1/reputation/score", response_model=ReputationScoreSchema)
async def get_reputation_score(
    agent_address: str = Query(...),
    request: Request = None,
    db: AsyncSession = Depends(get_session)
):
    """Calculate reputation score for an agent"""
    
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, None, "reputation", False)
    
    # Try cache first
    cached_score = await cache.get(f"reputation:{agent_address}")
    if cached_score:
        return ReputationScoreSchema(**cached_score)
    
    # Find agent
    agent_result = await db.execute(
        select(Agent).where(Agent.agent_address == agent_address)
    )
    agent = agent_result.scalar_one_or_none()
    
    if not agent:
        raise HTTPException(status_code=404, detail="Agent not found")
    
    # Calculate reputation based on feedback
    feedback_result = await db.execute(
        select(func.count(Feedback.id), func.avg(Feedback.rating))
        .where(Feedback.agent_server_id == agent.agent_id)
    )
    
    count, avg_rating = feedback_result.first()
    
    feedback_count = count or 0
    average_rating = float(avg_rating or 0)
    
    # Simple reputation calculation (can be made more sophisticated)
    if feedback_count == 0:
        reputation_score = 50.0  # Default score
    else:
        # Weight by number of feedback (more feedback = more reliable)
        confidence_factor = min(feedback_count / 10, 1.0)  # Max confidence at 10+ feedback
        reputation_score = average_rating * confidence_factor + 50.0 * (1 - confidence_factor)
    
    reputation_data = ReputationScoreSchema(
        agent_address=agent_address,
        reputation_score=reputation_score,
        feedback_count=feedback_count,
        average_rating=average_rating,
        calculated_at=datetime.utcnow()
    )
    
    # Cache the result
    await cache.set(f"reputation:{agent_address}", reputation_data.model_dump(), settings.reputation_cache_ttl)
    
    return reputation_data

# Agent verification endpoint
@app.post("/api/v1/agent/verify", response_model=dict)
async def verify_agent(
    verification_data: SignatureVerificationSchema,
    request: Request,
    db: AsyncSession = Depends(get_session)
):
    """Verify agent signature and registration"""
    
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, None, "verify", False)
    
    # Verify signature
    is_valid = web3_service.verify_signature(
        verification_data.message,
        verification_data.signature,
        verification_data.address
    )
    
    if not is_valid:
        return {"valid": False, "message": "Invalid signature"}
    
    # Check if agent is registered
    agent_result = await db.execute(
        select(Agent).where(
            and_(
                Agent.agent_address == verification_data.address,
                Agent.is_active == True
            )
        )
    )
    agent = agent_result.scalar_one_or_none()
    
    return {
        "valid": True,
        "registered": agent is not None,
        "agent_domain": agent.agent_domain if agent else None,
        "verified_at": datetime.utcnow().isoformat()
    }

# Metrics endpoints
@app.get("/metrics")
async def prometheus_metrics():
    """Prometheus metrics endpoint"""
    return await get_prometheus_metrics()

@app.get("/metrics/json")
async def json_metrics(
    request: Request,
    db: AsyncSession = Depends(get_session)
):
    """JSON metrics endpoint for application monitoring"""
    client_ip = extract_client_ip(request)
    await apply_rate_limit(client_ip, None, "metrics", False)
    
    return await get_application_metrics(db)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.server_host,
        port=settings.server_port,
        reload=settings.environment == "development"
    )