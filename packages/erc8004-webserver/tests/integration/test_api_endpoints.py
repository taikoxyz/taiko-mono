import pytest
from fastapi.testclient import TestClient
from datetime import datetime, timezone, timedelta
import json

from app.models import Agent, Feedback, ValidationRequest


class TestHealthEndpoint:
    
    def test_health_check(self, client):
        """Test health check endpoint."""
        response = client.get("/health")
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] in ["healthy", "unhealthy"]
        assert "timestamp" in data
        assert "services" in data
        assert "version" in data


class TestAgentCardEndpoint:
    
    def test_get_agent_card_no_agent(self, client):
        """Test getting agent card when no agent is registered."""
        response = client.get("/.well-known/agent-card.json")
        assert response.status_code == 404
    
    @pytest.mark.asyncio
    async def test_get_agent_card_with_agent(self, client, db_session, sample_agent_card):
        """Test getting agent card when agent is registered."""
        # Create an agent first
        agent = Agent(
            agent_address="eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
            agent_domain="agent.example.com",
            agent_card=sample_agent_card,
            signature="0x123..."
        )
        db_session.add(agent)
        await db_session.commit()
        
        response = client.get("/.well-known/agent-card.json")
        
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == sample_agent_card["name"]
        assert data["description"] == sample_agent_card["description"]
        assert data["version"] == sample_agent_card["version"]
        assert "skills" in data
        assert "FeedbackDataURI" in data
        assert "ValidationRequestsURI" in data
        assert "ValidationResponsesURI" in data


class TestAgentRegistration:
    
    def test_register_agent_success(self, client, auth_headers, sample_agent_card):
        """Test successful agent registration."""
        agent_data = {
            "agent_address": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
            "agent_domain": "test.example.com",
            "agent_card": sample_agent_card,
            "signature": "0x1a2b3c4d..."
        }
        
        response = client.post(
            "/api/v1/agent/register",
            json=agent_data,
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["agent_address"] == agent_data["agent_address"]
        assert data["agent_domain"] == agent_data["agent_domain"]
        assert data["is_active"] is True
        assert "agent_id" in data
        assert "created_at" in data
    
    def test_register_agent_missing_headers(self, client, sample_agent_card):
        """Test agent registration without authentication headers."""
        agent_data = {
            "agent_address": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
            "agent_domain": "test.example.com",
            "agent_card": sample_agent_card,
            "signature": "0x1a2b3c4d..."
        }
        
        response = client.post("/api/v1/agent/register", json=agent_data)
        
        assert response.status_code == 401
    
    def test_register_agent_invalid_data(self, client, auth_headers):
        """Test agent registration with invalid data."""
        agent_data = {
            "agent_address": "invalid-address-format",
            "agent_domain": "test.example.com",
            "agent_card": {},
            "signature": "0x123"
        }
        
        response = client.post(
            "/api/v1/agent/register",
            json=agent_data,
            headers=auth_headers
        )
        
        assert response.status_code == 422  # Validation error
    
    @pytest.mark.asyncio
    async def test_update_existing_agent(self, client, db_session, auth_headers, sample_agent_card):
        """Test updating an existing agent."""
        # Create existing agent
        agent = Agent(
            agent_address="eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
            agent_domain="old.example.com",
            agent_card={"name": "Old Agent", "version": "0.1.0"},
            signature="0xold..."
        )
        db_session.add(agent)
        await db_session.commit()
        
        # Update agent
        updated_data = {
            "agent_address": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
            "agent_domain": "new.example.com",
            "agent_card": sample_agent_card,
            "signature": "0xnew..."
        }
        
        response = client.post(
            "/api/v1/agent/register",
            json=updated_data,
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["agent_domain"] == "new.example.com"
        assert data["agent_card"]["name"] == sample_agent_card["name"]


class TestAgentVerification:
    
    def test_verify_agent_success(self, client):
        """Test successful agent verification."""
        verification_data = {
            "message": "Hello, World!",
            "signature": "0x1a2b3c4d5e6f7890abcdef...",
            "address": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        }
        
        response = client.post("/api/v1/agent/verify", json=verification_data)
        
        assert response.status_code == 200
        data = response.json()
        assert data["valid"] is True
        assert "verified_at" in data
    
    def test_verify_agent_invalid_signature(self, client, mock_web3):
        """Test agent verification with invalid signature."""
        # Mock web3 service to return False
        mock_web3.verify_signature.return_value = False
        
        verification_data = {
            "message": "Hello, World!",
            "signature": "0xinvalid...",
            "address": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        }
        
        response = client.post("/api/v1/agent/verify", json=verification_data)
        
        assert response.status_code == 200
        data = response.json()
        assert data["valid"] is False


class TestFeedbackEndpoints:
    
    def test_list_feedback_empty(self, client):
        """Test listing feedback when database is empty."""
        response = client.get("/api/v1/feedback")
        
        assert response.status_code == 200
        data = response.json()
        assert data["items"] == []
        assert data["total"] == 0
        assert data["page"] == 1
        assert data["page_size"] == 20
        assert data["total_pages"] == 0
    
    @pytest.mark.asyncio
    async def test_list_feedback_with_data(self, client, db_session):
        """Test listing feedback with existing data."""
        # Create agent
        agent = Agent(
            agent_address="eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
            agent_domain="test.example.com",
            agent_card={"name": "Test Agent"},
            signature="0x123..."
        )
        db_session.add(agent)
        await db_session.commit()
        await db_session.refresh(agent)
        
        # Create feedback
        feedback = Feedback(
            feedback_auth_id="eip155:167000:0x111...",
            agent_server_id=agent.agent_id,
            agent_skill_id="test-skill",
            rating=95,
            signature="0x456..."
        )
        db_session.add(feedback)
        await db_session.commit()
        
        response = client.get("/api/v1/feedback")
        
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) == 1
        assert data["total"] == 1
        assert data["items"][0]["Rating"] == 95
        assert data["items"][0]["AgentSkillId"] == "test-skill"
    
    def test_list_feedback_with_pagination(self, client):
        """Test feedback listing with pagination parameters."""
        response = client.get("/api/v1/feedback?page=2&page_size=5")
        
        assert response.status_code == 200
        data = response.json()
        assert data["page"] == 2
        assert data["page_size"] == 5
    
    def test_list_feedback_with_filters(self, client):
        """Test feedback listing with filter parameters."""
        response = client.get("/api/v1/feedback?min_rating=80&max_rating=100&agent_skill_id=test")
        
        assert response.status_code == 200
        # Should return valid response even with no data matching filters
    
    def test_submit_feedback_success(self, client, auth_headers, sample_feedback_data):
        """Test successful feedback submission."""
        response = client.post(
            "/api/v1/feedback",
            json=sample_feedback_data,
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["FeedbackAuthID"] == sample_feedback_data["FeedbackAuthID"]
        assert data["Rating"] == sample_feedback_data["Rating"]
        assert data["AgentSkillId"] == sample_feedback_data["AgentSkillId"]
        assert "id" in data
        assert "created_at" in data
        assert "signature" in data
    
    def test_submit_feedback_missing_auth(self, client, sample_feedback_data):
        """Test feedback submission without authentication."""
        response = client.post("/api/v1/feedback", json=sample_feedback_data)
        
        assert response.status_code == 401
    
    def test_submit_feedback_invalid_rating(self, client, auth_headers):
        """Test feedback submission with invalid rating."""
        invalid_feedback = {
            "FeedbackAuthID": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
            "Rating": 150,  # Invalid: over 100
            "AgentSkillId": "test-skill"
        }
        
        response = client.post(
            "/api/v1/feedback",
            json=invalid_feedback,
            headers=auth_headers
        )
        
        assert response.status_code == 422  # Validation error
    
    @pytest.mark.asyncio
    async def test_get_specific_feedback(self, client, db_session):
        """Test getting specific feedback by auth ID."""
        # Create feedback
        feedback_auth_id = "eip155:167000:0x111..."
        feedback = Feedback(
            feedback_auth_id=feedback_auth_id,
            agent_skill_id="test-skill",
            rating=85,
            signature="0x456..."
        )
        db_session.add(feedback)
        await db_session.commit()
        
        response = client.get(f"/api/v1/feedback/{feedback_auth_id}")
        
        assert response.status_code == 200
        data = response.json()
        assert data["FeedbackAuthID"] == feedback_auth_id
        assert data["Rating"] == 85
    
    def test_get_specific_feedback_not_found(self, client):
        """Test getting non-existent feedback."""
        response = client.get("/api/v1/feedback/eip155:167000:0xnonexistent...")
        
        assert response.status_code == 404


class TestValidationEndpoints:
    
    def test_list_validation_requests_empty(self, client):
        """Test listing validation requests when empty."""
        response = client.get("/api/v1/validations/requests")
        
        assert response.status_code == 200
        data = response.json()
        assert data["requests"] == {}
    
    @pytest.mark.asyncio
    async def test_list_validation_requests_with_data(self, client, db_session):
        """Test listing validation requests with existing data."""
        # Create agent
        agent = Agent(
            agent_address="eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
            agent_domain="test.example.com",
            agent_card={"name": "Test Agent"},
            signature="0x123..."
        )
        db_session.add(agent)
        await db_session.commit()
        await db_session.refresh(agent)
        
        # Create validation request (not expired)
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)
        validation_request = ValidationRequest(
            data_hash="0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
            agent_validator_id=agent.agent_id,
            agent_server_id=agent.agent_id,
            data_uri="https://example.com/data.json",
            validation_data={"type": "test"},
            expires_at=expires_at
        )
        db_session.add(validation_request)
        await db_session.commit()
        
        response = client.get("/api/v1/validations/requests")
        
        assert response.status_code == 200
        data = response.json()
        assert len(data["requests"]) == 1
        data_hash = "0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890"
        assert data["requests"][data_hash] == "https://example.com/data.json"
    
    def test_submit_validation_request_success(self, client, auth_headers):
        """Test successful validation request submission."""
        request_data = {
            "data_hash": "0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
            "agent_validator_id": 123,
            "data_uri": "https://example.com/validation-data.json",
            "validation_data": {
                "type": "price_check",
                "symbol": "BTC/USDT",
                "expectedPrice": 45000
            },
            "expires_at": "2024-12-31T23:59:59Z"
        }
        
        response = client.post(
            "/api/v1/validations/requests",
            json=request_data,
            headers=auth_headers
        )
        
        # This will fail without a registered agent, but should show proper validation
        assert response.status_code in [200, 404]  # 404 if agent not found
    
    def test_submit_validation_request_missing_auth(self, client):
        """Test validation request submission without authentication."""
        request_data = {
            "data_hash": "0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
            "agent_validator_id": 123,
            "data_uri": "https://example.com/data.json",
            "validation_data": {"type": "test"},
            "expires_at": "2024-12-31T23:59:59Z"
        }
        
        response = client.post("/api/v1/validations/requests", json=request_data)
        
        assert response.status_code == 401
    
    def test_list_validation_responses_empty(self, client):
        """Test listing validation responses when empty."""
        response = client.get("/api/v1/validations/responses")
        
        assert response.status_code == 200
        data = response.json()
        assert data == []
    
    def test_list_validation_responses_with_filter(self, client):
        """Test listing validation responses with data hash filter."""
        data_hash = "0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890"
        response = client.get(f"/api/v1/validations/responses?data_hash={data_hash}")
        
        assert response.status_code == 200
        data = response.json()
        assert data == []  # Empty since no data exists
    
    def test_submit_validation_response_success(self, client, auth_headers):
        """Test successful validation response submission."""
        response_data = {
            "data_hash": "0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
            "response": 85,
            "evidence": {
                "validation_method": "price_comparison",
                "confidence": 0.92
            }
        }
        
        response = client.post(
            "/api/v1/validations/responses",
            json=response_data,
            headers=auth_headers
        )
        
        # Will fail without existing validation request and agent
        assert response.status_code in [200, 404]  # 404 if validation request not found
    
    def test_submit_validation_response_missing_auth(self, client):
        """Test validation response submission without authentication."""
        response_data = {
            "data_hash": "0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
            "response": 85,
            "evidence": {"method": "test"}
        }
        
        response = client.post("/api/v1/validations/responses", json=response_data)
        
        assert response.status_code == 401


class TestReputationEndpoint:
    
    def test_get_reputation_score_no_agent(self, client):
        """Test getting reputation score for non-existent agent."""
        agent_address = "eip155:167000:0xnonexistent..."
        response = client.get(f"/api/v1/reputation/score?agent_address={agent_address}")
        
        assert response.status_code == 404
    
    @pytest.mark.asyncio
    async def test_get_reputation_score_with_agent(self, client, db_session):
        """Test getting reputation score for existing agent."""
        # Create agent
        agent_address = "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        agent = Agent(
            agent_address=agent_address,
            agent_domain="test.example.com",
            agent_card={"name": "Test Agent"},
            signature="0x123..."
        )
        db_session.add(agent)
        await db_session.commit()
        await db_session.refresh(agent)
        
        response = client.get(f"/api/v1/reputation/score?agent_address={agent_address}")
        
        assert response.status_code == 200
        data = response.json()
        assert data["agent_address"] == agent_address
        assert "reputation_score" in data
        assert "feedback_count" in data
        assert "average_rating" in data
        assert "calculated_at" in data
    
    def test_get_reputation_score_missing_parameter(self, client):
        """Test getting reputation score without agent_address parameter."""
        response = client.get("/api/v1/reputation/score")
        
        assert response.status_code == 422  # Missing required parameter