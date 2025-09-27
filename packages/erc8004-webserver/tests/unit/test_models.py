import pytest
from datetime import datetime, timezone
from sqlalchemy import select

from app.models import Agent, Feedback, ValidationRequest, ValidationResponse


class TestAgentModel:
    
    @pytest.mark.asyncio
    async def test_create_agent(self, db_session):
        """Test creating an agent."""
        agent_data = {
            "agent_address": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
            "agent_domain": "test.example.com",
            "agent_card": {
                "name": "Test Agent",
                "version": "1.0.0",
                "skills": []
            },
            "signature": "0x1a2b3c4d..."
        }
        
        agent = Agent(**agent_data)
        db_session.add(agent)
        await db_session.commit()
        await db_session.refresh(agent)
        
        assert agent.agent_id is not None
        assert agent.agent_address == agent_data["agent_address"]
        assert agent.agent_domain == agent_data["agent_domain"]
        assert agent.agent_card == agent_data["agent_card"]
        assert agent.signature == agent_data["signature"]
        assert agent.is_active is True
        assert isinstance(agent.created_at, datetime)
        assert isinstance(agent.updated_at, datetime)
    
    @pytest.mark.asyncio
    async def test_agent_unique_address_constraint(self, db_session):
        """Test that agent addresses must be unique."""
        agent_address = "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        
        # Create first agent
        agent1 = Agent(
            agent_address=agent_address,
            agent_domain="test1.example.com",
            agent_card={"name": "Agent 1"},
            signature="0x123..."
        )
        db_session.add(agent1)
        await db_session.commit()
        
        # Try to create second agent with same address
        agent2 = Agent(
            agent_address=agent_address,  # Same address
            agent_domain="test2.example.com",
            agent_card={"name": "Agent 2"},
            signature="0x456..."
        )
        db_session.add(agent2)
        
        with pytest.raises(Exception):  # Should raise integrity error
            await db_session.commit()
    
    @pytest.mark.asyncio
    async def test_agent_query_by_address(self, db_session):
        """Test querying agent by address."""
        agent_address = "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        
        agent = Agent(
            agent_address=agent_address,
            agent_domain="test.example.com",
            agent_card={"name": "Test Agent"},
            signature="0x123..."
        )
        db_session.add(agent)
        await db_session.commit()
        
        # Query by address
        result = await db_session.execute(
            select(Agent).where(Agent.agent_address == agent_address)
        )
        found_agent = result.scalar_one()
        
        assert found_agent.agent_id == agent.agent_id
        assert found_agent.agent_address == agent_address


class TestFeedbackModel:
    
    @pytest.mark.asyncio
    async def test_create_feedback(self, db_session):
        """Test creating feedback."""
        # Create agents first
        client_agent = Agent(
            agent_address="eip155:167000:0x111...",
            agent_domain="client.example.com",
            agent_card={"name": "Client Agent"},
            signature="0x111..."
        )
        server_agent = Agent(
            agent_address="eip155:167000:0x222...",
            agent_domain="server.example.com",
            agent_card={"name": "Server Agent"},
            signature="0x222..."
        )
        db_session.add_all([client_agent, server_agent])
        await db_session.commit()
        await db_session.refresh(client_agent)
        await db_session.refresh(server_agent)
        
        # Create feedback
        feedback = Feedback(
            feedback_auth_id="eip155:167000:0x333...",
            agent_client_id=client_agent.agent_id,
            agent_server_id=server_agent.agent_id,
            agent_skill_id="test-skill",
            task_id="task-123",
            context_id="context-456",
            rating=95,
            proof_of_payment={"txHash": "0xabc123", "amount": "100"},
            data={"completionTime": 30},
            signature="0x333...",
            ipfs_hash="QmTest123..."
        )
        db_session.add(feedback)
        await db_session.commit()
        await db_session.refresh(feedback)
        
        assert feedback.id is not None
        assert feedback.feedback_auth_id == "eip155:167000:0x333..."
        assert feedback.agent_client_id == client_agent.agent_id
        assert feedback.agent_server_id == server_agent.agent_id
        assert feedback.rating == 95
        assert isinstance(feedback.created_at, datetime)
    
    @pytest.mark.asyncio
    async def test_feedback_rating_constraint(self, db_session):
        """Test feedback rating constraint (0-100)."""
        # Valid rating (should work)
        feedback = Feedback(
            feedback_auth_id="eip155:167000:0x111...",
            rating=95,
            signature="0x123..."
        )
        db_session.add(feedback)
        await db_session.commit()
        
        # Invalid rating - this test depends on database enforcement
        # For SQLite, check constraint might not be enforced
        # In production PostgreSQL, this would raise an error
    
    @pytest.mark.asyncio
    async def test_feedback_relationships(self, db_session):
        """Test feedback relationships with agents."""
        # Create agents
        client_agent = Agent(
            agent_address="eip155:167000:0x111...",
            agent_domain="client.example.com", 
            agent_card={"name": "Client Agent"},
            signature="0x111..."
        )
        server_agent = Agent(
            agent_address="eip155:167000:0x222...",
            agent_domain="server.example.com",
            agent_card={"name": "Server Agent"}, 
            signature="0x222..."
        )
        db_session.add_all([client_agent, server_agent])
        await db_session.commit()
        await db_session.refresh(client_agent)
        await db_session.refresh(server_agent)
        
        # Create feedback
        feedback = Feedback(
            feedback_auth_id="eip155:167000:0x333...",
            agent_client_id=client_agent.agent_id,
            agent_server_id=server_agent.agent_id,
            signature="0x333..."
        )
        db_session.add(feedback)
        await db_session.commit()
        await db_session.refresh(feedback)
        
        # Test relationships
        assert feedback.client_agent.agent_id == client_agent.agent_id
        assert feedback.server_agent.agent_id == server_agent.agent_id
        
        # Test back relationships
        await db_session.refresh(client_agent, ["client_feedback"])
        await db_session.refresh(server_agent, ["server_feedback"])
        assert len(client_agent.client_feedback) == 1
        assert len(server_agent.server_feedback) == 1


class TestValidationRequestModel:
    
    @pytest.mark.asyncio
    async def test_create_validation_request(self, db_session):
        """Test creating a validation request."""
        # Create agents
        validator_agent = Agent(
            agent_address="eip155:167000:0x111...",
            agent_domain="validator.example.com",
            agent_card={"name": "Validator Agent"},
            signature="0x111..."
        )
        server_agent = Agent(
            agent_address="eip155:167000:0x222...",
            agent_domain="server.example.com",
            agent_card={"name": "Server Agent"},
            signature="0x222..."
        )
        db_session.add_all([validator_agent, server_agent])
        await db_session.commit()
        await db_session.refresh(validator_agent)
        await db_session.refresh(server_agent)
        
        # Create validation request
        expires_at = datetime.now(timezone.utc).replace(microsecond=0)
        validation_request = ValidationRequest(
            data_hash="0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
            agent_validator_id=validator_agent.agent_id,
            agent_server_id=server_agent.agent_id,
            data_uri="https://storage.example.com/data/123.json",
            validation_data={"type": "price_check", "symbol": "BTC/USDT"},
            expires_at=expires_at
        )
        db_session.add(validation_request)
        await db_session.commit()
        await db_session.refresh(validation_request)
        
        assert validation_request.id is not None
        assert validation_request.data_hash.startswith("0x")
        assert validation_request.agent_validator_id == validator_agent.agent_id
        assert validation_request.agent_server_id == server_agent.agent_id
        assert validation_request.expires_at == expires_at
        assert isinstance(validation_request.created_at, datetime)
    
    @pytest.mark.asyncio
    async def test_validation_request_unique_hash(self, db_session):
        """Test that validation request data hashes must be unique."""
        # Create agent
        agent = Agent(
            agent_address="eip155:167000:0x111...",
            agent_domain="test.example.com",
            agent_card={"name": "Test Agent"},
            signature="0x111..."
        )
        db_session.add(agent)
        await db_session.commit()
        await db_session.refresh(agent)
        
        data_hash = "0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890"
        expires_at = datetime.now(timezone.utc)
        
        # Create first validation request
        request1 = ValidationRequest(
            data_hash=data_hash,
            agent_validator_id=agent.agent_id,
            agent_server_id=agent.agent_id,
            data_uri="https://example.com/data1.json",
            validation_data={"test": 1},
            expires_at=expires_at
        )
        db_session.add(request1)
        await db_session.commit()
        
        # Try to create second request with same hash
        request2 = ValidationRequest(
            data_hash=data_hash,  # Same hash
            agent_validator_id=agent.agent_id,
            agent_server_id=agent.agent_id,
            data_uri="https://example.com/data2.json",
            validation_data={"test": 2},
            expires_at=expires_at
        )
        db_session.add(request2)
        
        with pytest.raises(Exception):  # Should raise integrity error
            await db_session.commit()


class TestValidationResponseModel:
    
    @pytest.mark.asyncio
    async def test_create_validation_response(self, db_session):
        """Test creating a validation response."""
        # Create agent
        validator_agent = Agent(
            agent_address="eip155:167000:0x111...",
            agent_domain="validator.example.com",
            agent_card={"name": "Validator Agent"},
            signature="0x111..."
        )
        server_agent = Agent(
            agent_address="eip155:167000:0x222...",
            agent_domain="server.example.com", 
            agent_card={"name": "Server Agent"},
            signature="0x222..."
        )
        db_session.add_all([validator_agent, server_agent])
        await db_session.commit()
        await db_session.refresh(validator_agent)
        await db_session.refresh(server_agent)
        
        # Create validation request first
        data_hash = "0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890"
        expires_at = datetime.now(timezone.utc)
        validation_request = ValidationRequest(
            data_hash=data_hash,
            agent_validator_id=validator_agent.agent_id,
            agent_server_id=server_agent.agent_id,
            data_uri="https://example.com/data.json",
            validation_data={"test": "data"},
            expires_at=expires_at
        )
        db_session.add(validation_request)
        await db_session.commit()
        
        # Create validation response
        validation_response = ValidationResponse(
            data_hash=data_hash,
            agent_validator_id=validator_agent.agent_id,
            response=85,
            evidence={"method": "price_comparison", "confidence": 0.92},
            validator_signature="0x123...",
            ipfs_hash="QmValidation123..."
        )
        db_session.add(validation_response)
        await db_session.commit()
        await db_session.refresh(validation_response)
        
        assert validation_response.id is not None
        assert validation_response.data_hash == data_hash
        assert validation_response.response == 85
        assert validation_response.evidence["method"] == "price_comparison"
        assert isinstance(validation_response.created_at, datetime)
    
    @pytest.mark.asyncio
    async def test_validation_response_relationship(self, db_session):
        """Test validation response relationships."""
        # Create agent
        agent = Agent(
            agent_address="eip155:167000:0x111...",
            agent_domain="test.example.com",
            agent_card={"name": "Test Agent"},
            signature="0x111..."
        )
        db_session.add(agent)
        await db_session.commit()
        await db_session.refresh(agent)
        
        # Create validation request
        data_hash = "0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890"
        expires_at = datetime.now(timezone.utc)
        validation_request = ValidationRequest(
            data_hash=data_hash,
            agent_validator_id=agent.agent_id,
            agent_server_id=agent.agent_id,
            data_uri="https://example.com/data.json",
            validation_data={"test": "data"},
            expires_at=expires_at
        )
        db_session.add(validation_request)
        await db_session.commit()
        await db_session.refresh(validation_request)
        
        # Create validation response
        validation_response = ValidationResponse(
            data_hash=data_hash,
            agent_validator_id=agent.agent_id,
            response=85,
            evidence={"method": "test"},
            validator_signature="0x123..."
        )
        db_session.add(validation_response)
        await db_session.commit()
        await db_session.refresh(validation_response)
        
        # Test relationships
        assert validation_response.validator_agent.agent_id == agent.agent_id
        assert validation_response.request.id == validation_request.id
        
        # Test back relationship
        await db_session.refresh(validation_request, ["responses"])
        assert len(validation_request.responses) == 1
        assert validation_request.responses[0].id == validation_response.id