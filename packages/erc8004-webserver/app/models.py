from sqlalchemy import Integer, String, Text, Boolean, DateTime, JSON, CheckConstraint, Index, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from datetime import datetime, timezone
from typing import Optional, Any, Dict, List
from .database import Base


class Agent(Base):
    __tablename__ = "agents"
    
    agent_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    agent_address: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    agent_domain: Mapped[str] = mapped_column(String(255), nullable=False)
    agent_card: Mapped[Dict[str, Any]] = mapped_column(JSON, nullable=False)
    signature: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc)
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    
    # Relationships
    client_feedback: Mapped[List["Feedback"]] = relationship(
        "Feedback", 
        foreign_keys="[Feedback.agent_client_id]",
        back_populates="client_agent"
    )
    server_feedback: Mapped[List["Feedback"]] = relationship(
        "Feedback", 
        foreign_keys="[Feedback.agent_server_id]",
        back_populates="server_agent"
    )
    validation_requests: Mapped[List["ValidationRequest"]] = relationship(
        "ValidationRequest",
        foreign_keys="[ValidationRequest.agent_server_id]",
        back_populates="server_agent"
    )
    validation_responses: Mapped[List["ValidationResponse"]] = relationship(
        "ValidationResponse",
        foreign_keys="[ValidationResponse.agent_validator_id]",
        back_populates="validator_agent"
    )
    
    __table_args__ = (
        Index('idx_agent_address', 'agent_address'),
        Index('idx_agent_domain', 'agent_domain'),
        Index('idx_agent_active', 'is_active'),
    )


class Feedback(Base):
    __tablename__ = "feedback"
    
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    feedback_auth_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    agent_client_id: Mapped[Optional[int]] = mapped_column(
        Integer, 
        ForeignKey("agents.agent_id", ondelete="SET NULL")
    )
    agent_server_id: Mapped[Optional[int]] = mapped_column(
        Integer, 
        ForeignKey("agents.agent_id", ondelete="SET NULL")
    )
    agent_skill_id: Mapped[Optional[str]] = mapped_column(String(255))
    task_id: Mapped[Optional[str]] = mapped_column(String(255))
    context_id: Mapped[Optional[str]] = mapped_column(String(255))
    rating: Mapped[Optional[int]] = mapped_column(
        Integer, 
        CheckConstraint('rating >= 0 AND rating <= 100', name='chk_rating_range')
    )
    proof_of_payment: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON)
    data: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON)
    signature: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        default=lambda: datetime.now(timezone.utc)
    )
    ipfs_hash: Mapped[Optional[str]] = mapped_column(String(255))
    
    # Relationships
    client_agent: Mapped[Optional["Agent"]] = relationship(
        "Agent", 
        foreign_keys=[agent_client_id],
        back_populates="client_feedback"
    )
    server_agent: Mapped[Optional["Agent"]] = relationship(
        "Agent", 
        foreign_keys=[agent_server_id],
        back_populates="server_feedback"
    )
    
    __table_args__ = (
        # Prevent duplicate feedback per task from the same client
        UniqueConstraint(
            'agent_client_id', 'task_id', 
            name='uq_feedback_client_task'
        ),
        # Prevent duplicate feedback for the same agent skill per client
        UniqueConstraint(
            'agent_client_id', 'agent_server_id', 'agent_skill_id', 'context_id',
            name='uq_feedback_client_server_skill_context'
        ),
        # Indexes for performance
        Index('idx_feedback_auth_id', 'feedback_auth_id'),
        Index('idx_feedback_server_id', 'agent_server_id'),
        Index('idx_feedback_client_id', 'agent_client_id'),
        Index('idx_feedback_skill_id', 'agent_skill_id'),
        Index('idx_feedback_task_id', 'task_id'),
        Index('idx_feedback_created_at', 'created_at'),
        # Composite index for common query patterns
        Index('idx_feedback_server_skill', 'agent_server_id', 'agent_skill_id'),
        Index('idx_feedback_client_server', 'agent_client_id', 'agent_server_id'),
    )


class ValidationRequest(Base):
    __tablename__ = "validation_requests"
    
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    data_hash: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    agent_validator_id: Mapped[Optional[int]] = mapped_column(
        Integer, 
        ForeignKey("agents.agent_id", ondelete="CASCADE"),
        nullable=True  # Allow null for public validation requests
    )
    agent_server_id: Mapped[int] = mapped_column(
        Integer, 
        ForeignKey("agents.agent_id", ondelete="CASCADE"),
        nullable=False
    )
    data_uri: Mapped[str] = mapped_column(Text, nullable=False)
    validation_data: Mapped[Dict[str, Any]] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        default=lambda: datetime.now(timezone.utc)
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    
    # Relationships
    validator_agent: Mapped[Optional["Agent"]] = relationship(
        "Agent", 
        foreign_keys=[agent_validator_id]
    )
    server_agent: Mapped["Agent"] = relationship(
        "Agent", 
        foreign_keys=[agent_server_id],
        back_populates="validation_requests"
    )
    responses: Mapped[List["ValidationResponse"]] = relationship(
        "ValidationResponse",
        back_populates="request"
    )
    
    __table_args__ = (
        Index('idx_validation_req_hash', 'data_hash'),
        Index('idx_validation_req_validator', 'agent_validator_id'),
        Index('idx_validation_req_server', 'agent_server_id'),
        Index('idx_validation_req_expires', 'expires_at'),
    )


class ValidationResponse(Base):
    __tablename__ = "validation_responses"
    
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    data_hash: Mapped[str] = mapped_column(
        String(255), 
        ForeignKey("validation_requests.data_hash", ondelete="CASCADE"),
        nullable=False
    )
    agent_validator_id: Mapped[int] = mapped_column(
        Integer, 
        ForeignKey("agents.agent_id", ondelete="CASCADE"),
        nullable=False
    )
    response: Mapped[int] = mapped_column(
        Integer, 
        CheckConstraint('response >= 0 AND response <= 100', name='chk_response_range'),
        nullable=False
    )
    evidence: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON)
    validator_signature: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        default=lambda: datetime.now(timezone.utc)
    )
    ipfs_hash: Mapped[Optional[str]] = mapped_column(String(255))
    
    # Relationships
    validator_agent: Mapped["Agent"] = relationship(
        "Agent", 
        foreign_keys=[agent_validator_id],
        back_populates="validation_responses"
    )
    request: Mapped["ValidationRequest"] = relationship(
        "ValidationRequest",
        back_populates="responses"
    )
    
    __table_args__ = (
        Index('idx_validation_resp_hash', 'data_hash'),
        Index('idx_validation_resp_validator', 'agent_validator_id'),
        Index('idx_validation_resp_created', 'created_at'),
    )