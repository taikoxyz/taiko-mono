from pydantic import BaseModel, Field, validator, root_validator
from typing import Dict, List, Any, Optional, Union
from datetime import datetime
from enum import Enum


class TrustModel(str, Enum):
    REPUTATION = "reputation"
    STAKE = "stake"
    TEE = "tee"


class SkillSchema(BaseModel):
    skillId: str = Field(..., description="Unique identifier for the skill")
    description: str = Field(..., description="Description of the skill")
    inputs: Dict[str, Any] = Field(default_factory=dict, description="Input schema for the skill")
    outputs: Dict[str, Any] = Field(default_factory=dict, description="Output schema for the skill")


class RegistrationSchema(BaseModel):
    agentId: int = Field(..., description="Unique agent identifier")
    agentAddress: str = Field(..., pattern=r"^eip155:\d+:0x[a-fA-F0-9]{40}$", description="CAIP-10 format agent address")
    signature: str = Field(..., pattern=r"^0x[a-fA-F0-9]{130}$", description="Ethereum signature")


class AgentCardSchema(BaseModel):
    name: str = Field(..., description="Agent name")
    description: str = Field(..., description="Agent description")
    version: str = Field(..., description="Agent version")
    skills: List[SkillSchema] = Field(default_factory=list, description="Agent skills")
    registrations: List[RegistrationSchema] = Field(default_factory=list, description="Agent registrations")
    trustModels: List[TrustModel] = Field(default_factory=list, description="Supported trust models")
    FeedbackDataURI: str = Field(..., description="URI for feedback data endpoint")
    ValidationRequestsURI: str = Field(..., description="URI for validation requests endpoint")
    ValidationResponsesURI: str = Field(..., description="URI for validation responses endpoint")


class AgentCreateSchema(BaseModel):
    agent_address: str = Field(..., pattern=r"^eip155:\d+:0x[a-fA-F0-9]{40}$")
    agent_domain: str = Field(..., description="Agent domain")
    agent_card: AgentCardSchema = Field(..., description="Agent card data")
    signature: str = Field(..., pattern=r"^0x[a-fA-F0-9]{130}$")


class AgentResponseSchema(BaseModel):
    agent_id: int
    agent_address: str
    agent_domain: str
    agent_card: AgentCardSchema
    signature: str
    created_at: datetime
    updated_at: datetime
    is_active: bool

    class Config:
        from_attributes = True


class FeedbackCreateSchema(BaseModel):
    FeedbackAuthID: str = Field(..., pattern=r"^eip155:\d+:0x[a-fA-F0-9]{40}$")
    AgentSkillId: Optional[str] = None
    TaskId: Optional[str] = None
    contextId: Optional[str] = None
    Rating: Optional[int] = Field(None, ge=0, le=100)
    ProofOfPayment: Optional[Dict[str, Any]] = Field(default_factory=dict)
    Data: Optional[Dict[str, Any]] = Field(default_factory=dict)


class FeedbackResponseSchema(BaseModel):
    id: int
    FeedbackAuthID: str
    AgentSkillId: Optional[str]
    TaskId: Optional[str]
    contextId: Optional[str]
    Rating: Optional[int]
    ProofOfPayment: Optional[Dict[str, Any]]
    Data: Optional[Dict[str, Any]]
    signature: str
    created_at: datetime
    ipfs_hash: Optional[str]

    class Config:
        from_attributes = True


class ValidationRequestCreateSchema(BaseModel):
    data_hash: str = Field(..., pattern=r"^[a-fA-F0-9]{64}$")
    agent_validator_id: int = Field(..., gt=0)
    data_uri: str = Field(..., description="URI to validation data")
    validation_data: Dict[str, Any] = Field(..., description="Validation request data")
    expires_at: datetime = Field(..., description="Expiration timestamp")


class ValidationRequestResponseSchema(BaseModel):
    id: int
    data_hash: str
    agent_validator_id: int
    agent_server_id: int
    data_uri: str
    validation_data: Dict[str, Any]
    created_at: datetime
    expires_at: datetime

    class Config:
        from_attributes = True


class ValidationResponseCreateSchema(BaseModel):
    data_hash: str = Field(..., pattern=r"^[a-fA-F0-9]{64}$")
    response: int = Field(..., ge=0, le=100)
    evidence: Optional[Dict[str, Any]] = Field(default_factory=dict)


class ValidationResponseResponseSchema(BaseModel):
    id: int
    data_hash: str
    agent_validator_id: int
    response: int
    evidence: Optional[Dict[str, Any]]
    validator_signature: str
    created_at: datetime
    ipfs_hash: Optional[str]

    class Config:
        from_attributes = True


class ValidationRequestListSchema(BaseModel):
    """Schema for validation request list endpoint that returns DataHash -> DataURI mapping"""
    requests: Dict[str, str] = Field(..., description="Mapping of DataHash to DataURI")


class ReputationScoreSchema(BaseModel):
    agent_address: str
    reputation_score: float = Field(..., ge=0.0, le=100.0)
    feedback_count: int = Field(..., ge=0)
    average_rating: float = Field(..., ge=0.0, le=100.0)
    calculated_at: datetime


class HealthCheckSchema(BaseModel):
    status: str
    timestamp: datetime
    services: Dict[str, str] = Field(default_factory=dict)
    version: str = "1.0.0"


class ErrorResponseSchema(BaseModel):
    error: str
    message: str
    timestamp: datetime
    request_id: Optional[str] = None


class PaginatedResponseSchema(BaseModel):
    items: List[Any]
    total: int
    page: int
    page_size: int
    total_pages: int


class SignatureVerificationSchema(BaseModel):
    message: str = Field(..., description="Message that was signed")
    signature: str = Field(..., pattern=r"^0x[a-fA-F0-9]{130}$")
    address: str = Field(..., pattern=r"^eip155:\d+:0x[a-fA-F0-9]{40}$")


class MetricsSchema(BaseModel):
    """Schema for metrics endpoint"""
    total_agents: int
    total_feedback: int
    total_validation_requests: int
    total_validation_responses: int
    average_reputation: float
    uptime_seconds: float