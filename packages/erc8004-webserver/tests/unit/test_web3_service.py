import pytest
from unittest.mock import Mock, patch
from app.web3_service import Web3Service


class TestWeb3Service:
    
    def test_parse_caip10_address_valid(self):
        """Test parsing valid CAIP-10 address."""
        service = Web3Service()
        
        address, chain_id = service.parse_caip10_address(
            "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        )
        
        assert address == "0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        assert chain_id == 167000
    
    def test_parse_caip10_address_invalid_format(self):
        """Test parsing invalid CAIP-10 format."""
        service = Web3Service()
        
        # Missing parts
        address, chain_id = service.parse_caip10_address("eip155:167000")
        assert address is None
        assert chain_id is None
        
        # Wrong namespace
        address, chain_id = service.parse_caip10_address("btc:1:0x742d35Cc...")
        assert address is None
        assert chain_id is None
        
        # Invalid chain ID
        address, chain_id = service.parse_caip10_address("eip155:abc:0x742d35Cc...")
        assert address is None
        assert chain_id is None
    
    def test_create_eip712_domain(self):
        """Test EIP-712 domain creation."""
        service = Web3Service()
        
        domain = service.create_eip712_domain()
        
        assert domain["name"] == "ERC8004-OffChainStorage"
        assert domain["version"] == "1"
        assert "chainId" in domain
        assert "verifyingContract" in domain
    
    def test_hash_agent_card(self):
        """Test agent card hashing."""
        service = Web3Service()
        
        agent_card = {
            "name": "Test Agent",
            "version": "1.0.0",
            "skills": []
        }
        
        hash1 = service.hash_agent_card(agent_card)
        hash2 = service.hash_agent_card(agent_card)
        
        # Should be deterministic
        assert hash1 == hash2
        assert hash1.startswith("0x")
        assert len(hash1) == 66  # 0x + 64 hex chars
        
        # Different cards should have different hashes
        agent_card2 = {**agent_card, "name": "Different Agent"}
        hash3 = service.hash_agent_card(agent_card2)
        assert hash1 != hash3
    
    def test_hash_feedback_data(self):
        """Test feedback data hashing."""
        service = Web3Service()
        
        proof_of_payment = {"txHash": "0xabc123", "amount": "100"}
        data = {"completionTime": 30}
        
        hash1 = service.hash_feedback_data(proof_of_payment, data)
        hash2 = service.hash_feedback_data(proof_of_payment, data)
        
        # Should be deterministic
        assert hash1 == hash2
        assert hash1.startswith("0x")
        
        # None values should work
        hash3 = service.hash_feedback_data(None, None)
        assert hash3.startswith("0x")
    
    def test_generate_ipfs_hash(self):
        """Test IPFS hash generation."""
        service = Web3Service()
        
        data = {"test": "data", "number": 123}
        
        hash1 = service.generate_ipfs_hash(data)
        hash2 = service.generate_ipfs_hash(data)
        
        # Should be deterministic
        assert hash1 == hash2
        assert hash1.startswith("Qm")
        assert len(hash1) == 46  # Qm + 44 chars
        
        # Different data should have different hashes
        data2 = {"test": "different", "number": 456}
        hash3 = service.generate_ipfs_hash(data2)
        assert hash1 != hash3
    
    def test_create_agent_registration_message(self):
        """Test agent registration message creation."""
        service = Web3Service()
        
        agent_address = "0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        agent_domain = "test.example.com"
        agent_card = {"name": "Test Agent", "version": "1.0.0"}
        
        message = service.create_agent_registration_message(
            agent_address, agent_domain, agent_card
        )
        
        assert message["primaryType"] == "AgentRegistration"
        assert "domain" in message
        assert "types" in message
        assert "message" in message
        
        # Check message content
        msg = message["message"]
        assert msg["agentAddress"] == agent_address
        assert msg["agentDomain"] == agent_domain
        assert "agentCardHash" in msg
        assert "timestamp" in msg
    
    def test_create_feedback_message(self):
        """Test feedback message creation."""
        service = Web3Service()
        
        message = service.create_feedback_message(
            feedback_auth_id="eip155:167000:0x123...",
            agent_skill_id="test-skill",
            task_id="task-123",
            context_id="context-456",
            rating=95,
            proof_of_payment={"txHash": "0xabc"},
            data={"accuracy": 0.98}
        )
        
        assert message["primaryType"] == "FeedbackSubmission"
        assert "domain" in message
        assert "types" in message
        assert "message" in message
        
        # Check message content
        msg = message["message"]
        assert msg["feedbackAuthID"] == "eip155:167000:0x123..."
        assert msg["agentSkillId"] == "test-skill"
        assert msg["rating"] == 95
    
    def test_create_validation_response_message(self):
        """Test validation response message creation."""
        service = Web3Service()
        
        message = service.create_validation_response_message(
            data_hash="0xabc123...",
            response=85,
            evidence={"method": "price_check"}
        )
        
        assert message["primaryType"] == "ValidationResponse"
        assert "domain" in message
        assert "types" in message
        assert "message" in message
        
        # Check message content
        msg = message["message"]
        assert msg["dataHash"] == "0xabc123..."
        assert msg["response"] == 85
    
    @patch('app.web3_service.Web3')
    def test_verify_signature_success(self, mock_web3_class):
        """Test successful signature verification."""
        # Setup mock
        mock_w3 = Mock()
        mock_web3_class.return_value = mock_w3
        mock_w3.eth.account.recover_message.return_value = "0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        
        service = Web3Service()
        
        result = service.verify_signature(
            message="test message",
            signature="0x1a2b3c4d...",
            expected_address="0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        )
        
        assert result is True
    
    @patch('app.web3_service.Web3')
    def test_verify_signature_with_caip10(self, mock_web3_class):
        """Test signature verification with CAIP-10 address."""
        # Setup mock
        mock_w3 = Mock()
        mock_web3_class.return_value = mock_w3
        mock_w3.eth.account.recover_message.return_value = "0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        
        service = Web3Service()
        
        result = service.verify_signature(
            message="test message",
            signature="0x1a2b3c4d...",
            expected_address="eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        )
        
        assert result is True
    
    @patch('app.web3_service.Web3')
    def test_verify_signature_failure(self, mock_web3_class):
        """Test signature verification failure."""
        # Setup mock
        mock_w3 = Mock()
        mock_web3_class.return_value = mock_w3
        mock_w3.eth.account.recover_message.return_value = "0xdifferent_address"
        
        service = Web3Service()
        
        result = service.verify_signature(
            message="test message",
            signature="0x1a2b3c4d...",
            expected_address="0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        )
        
        assert result is False
    
    @patch('app.web3_service.Web3')
    def test_verify_signature_exception(self, mock_web3_class):
        """Test signature verification with exception."""
        # Setup mock to raise exception
        mock_w3 = Mock()
        mock_web3_class.return_value = mock_w3
        mock_w3.eth.account.recover_message.side_effect = Exception("Invalid signature")
        
        service = Web3Service()
        
        result = service.verify_signature(
            message="test message",
            signature="invalid_signature",
            expected_address="0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
        )
        
        assert result is False