from web3 import Web3
from eth_account.messages import encode_defunct, encode_structured_data
from eth_utils import to_checksum_address, is_address
from typing import Dict, Any, Optional, Tuple
import structlog
import hashlib
import re
import time
from .config import settings

logger = structlog.get_logger()


class Web3Service:
    def __init__(self):
        self.w3 = Web3(Web3.HTTPProvider(settings.web3_provider))
        
    def parse_caip10_address(self, caip10_address: str) -> Tuple[Optional[str], Optional[int]]:
        """
        Parse CAIP-10 address format: namespace:reference:address
        Example: eip155:1:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8
        """
        try:
            parts = caip10_address.split(':')
            if len(parts) != 3:
                return None, None
                
            namespace, chain_id_str, address = parts
            
            if namespace != 'eip155':
                return None, None
                
            chain_id = int(chain_id_str)
            
            if not is_address(address):
                return None, None
                
            return to_checksum_address(address), chain_id
            
        except (ValueError, AttributeError) as e:
            logger.error("Failed to parse CAIP-10 address", address=caip10_address, error=str(e))
            return None, None
    
    def create_eip712_domain(self) -> Dict[str, Any]:
        """Create EIP-712 domain separator"""
        return {
            "name": "ERC8004-OffChainStorage",
            "version": "1",
            "chainId": settings.chain_id,
            "verifyingContract": settings.contract_address or "0x0000000000000000000000000000000000000000"
        }
    
    def create_agent_registration_message(
        self, 
        agent_address: str, 
        agent_domain: str, 
        agent_card: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Create EIP-712 message for agent registration"""
        return {
            "domain": self.create_eip712_domain(),
            "primaryType": "AgentRegistration",
            "types": {
                "EIP712Domain": [
                    {"name": "name", "type": "string"},
                    {"name": "version", "type": "string"},
                    {"name": "chainId", "type": "uint256"},
                    {"name": "verifyingContract", "type": "address"}
                ],
                "AgentRegistration": [
                    {"name": "agentAddress", "type": "address"},
                    {"name": "agentDomain", "type": "string"},
                    {"name": "agentCardHash", "type": "bytes32"},
                    {"name": "timestamp", "type": "uint256"}
                ]
            },
            "message": {
                "agentAddress": agent_address,
                "agentDomain": agent_domain,
                "agentCardHash": self.hash_agent_card(agent_card),
                "timestamp": int(time.time())
            }
        }
    
    def create_feedback_message(
        self, 
        feedback_auth_id: str,
        agent_skill_id: Optional[str],
        task_id: Optional[str],
        context_id: Optional[str],
        rating: Optional[int],
        proof_of_payment: Optional[Dict[str, Any]],
        data: Optional[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Create EIP-712 message for feedback submission"""
        return {
            "domain": self.create_eip712_domain(),
            "primaryType": "FeedbackSubmission",
            "types": {
                "EIP712Domain": [
                    {"name": "name", "type": "string"},
                    {"name": "version", "type": "string"},
                    {"name": "chainId", "type": "uint256"},
                    {"name": "verifyingContract", "type": "address"}
                ],
                "FeedbackSubmission": [
                    {"name": "feedbackAuthID", "type": "string"},
                    {"name": "agentSkillId", "type": "string"},
                    {"name": "taskId", "type": "string"},
                    {"name": "contextId", "type": "string"},
                    {"name": "rating", "type": "uint256"},
                    {"name": "dataHash", "type": "bytes32"}
                ]
            },
            "message": {
                "feedbackAuthID": feedback_auth_id,
                "agentSkillId": agent_skill_id or "",
                "taskId": task_id or "",
                "contextId": context_id or "",
                "rating": rating or 0,
                "dataHash": self.hash_feedback_data(proof_of_payment, data)
            }
        }
    
    def create_validation_response_message(
        self,
        data_hash: str,
        response: int,
        evidence: Optional[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Create EIP-712 message for validation response"""
        return {
            "domain": self.create_eip712_domain(),
            "primaryType": "ValidationResponse",
            "types": {
                "EIP712Domain": [
                    {"name": "name", "type": "string"},
                    {"name": "version", "type": "string"},
                    {"name": "chainId", "type": "uint256"},
                    {"name": "verifyingContract", "type": "address"}
                ],
                "ValidationResponse": [
                    {"name": "dataHash", "type": "string"},
                    {"name": "response", "type": "uint256"},
                    {"name": "evidenceHash", "type": "bytes32"}
                ]
            },
            "message": {
                "dataHash": data_hash,
                "response": response,
                "evidenceHash": self.hash_evidence(evidence)
            }
        }
    
    def hash_agent_card(self, agent_card: Dict[str, Any]) -> str:
        """Create deterministic hash of agent card"""
        card_str = str(sorted(agent_card.items()))
        return Web3.keccak(text=card_str).hex()
    
    def hash_feedback_data(
        self, 
        proof_of_payment: Optional[Dict[str, Any]], 
        data: Optional[Dict[str, Any]]
    ) -> str:
        """Create deterministic hash of feedback data"""
        combined_data = {
            "proofOfPayment": proof_of_payment or {},
            "data": data or {}
        }
        data_str = str(sorted(combined_data.items()))
        return Web3.keccak(text=data_str).hex()
    
    def hash_evidence(self, evidence: Optional[Dict[str, Any]]) -> str:
        """Create deterministic hash of evidence data"""
        evidence_str = str(sorted((evidence or {}).items()))
        return Web3.keccak(text=evidence_str).hex()
    
    def verify_signature(
        self, 
        message: str, 
        signature: str, 
        expected_address: str
    ) -> bool:
        """Verify simple message signature"""
        try:
            # Clean up signature format
            if not signature.startswith('0x'):
                signature = '0x' + signature
                
            # Parse expected address from CAIP-10 format if needed
            if ':' in expected_address:
                expected_address, _ = self.parse_caip10_address(expected_address)
                if not expected_address:
                    return False
            
            expected_address = to_checksum_address(expected_address)
            
            # Create message hash
            message_hash = encode_defunct(text=message)
            
            # Recover signer address
            recovered_address = self.w3.eth.account.recover_message(
                message_hash, 
                signature=signature
            )
            
            return to_checksum_address(recovered_address) == expected_address
            
        except Exception as e:
            logger.error("Signature verification failed", error=str(e))
            return False
    
    def verify_eip712_signature(
        self, 
        structured_data: Dict[str, Any], 
        signature: str, 
        expected_address: str
    ) -> bool:
        """Verify EIP-712 structured data signature"""
        try:
            # Clean up signature format
            if not signature.startswith('0x'):
                signature = '0x' + signature
                
            # Parse expected address from CAIP-10 format if needed  
            if ':' in expected_address:
                expected_address, _ = self.parse_caip10_address(expected_address)
                if not expected_address:
                    return False
            
            expected_address = to_checksum_address(expected_address)
            
            # Encode structured data
            encoded_data = encode_structured_data(structured_data)
            
            # Recover signer address
            recovered_address = self.w3.eth.account.recover_message(
                encoded_data, 
                signature=signature
            )
            
            return to_checksum_address(recovered_address) == expected_address
            
        except Exception as e:
            logger.error("EIP-712 signature verification failed", error=str(e))
            return False
    
    def generate_ipfs_hash(self, data: Any) -> str:
        """Generate IPFS-compatible hash for data"""
        import json
        
        # Serialize data consistently
        if isinstance(data, dict):
            data_str = json.dumps(data, sort_keys=True, separators=(',', ':'))
        else:
            data_str = str(data)
        
        # Create SHA-256 hash
        sha256_hash = hashlib.sha256(data_str.encode('utf-8')).digest()
        
        # IPFS hash format (simplified - just using SHA-256)
        # In production, you'd use proper IPFS hashing
        return 'Qm' + sha256_hash.hex()[:44]


# Global Web3 service instance
web3_service = Web3Service()