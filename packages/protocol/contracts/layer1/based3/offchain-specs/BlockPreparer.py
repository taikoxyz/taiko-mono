from typing import Optional
from eth_typing import Address, HexStr
import hashlib
from IShasta import (
    ProposalContent, ProtoState, BlockInput, BlockHeaderPartial, Proposal
)


class BlockPreparer:
    """Handles preparation of build block input from various sources."""
    
    # Constants
    L1_BLOCK_TIME = 12
    MAX_BLOCK_TIMESTAMP_OFFSET = L1_BLOCK_TIME * 8
    MIN_L2_BLOCK_TIME = 1
    
    DEFAULT_GAS_ISSUANCE_PER_SECOND = 1_000_000
    GAS_ISSUANCE_PER_SECOND_MAX_OFFSET = 101
    GAS_ISSUANCE_PER_SECOND_MIN_OFFSET = 99
    
    def prepare_block_input(
        self,
        proposal: Proposal,  # from L1
        reference_block_header: BlockHeaderPartial,  # from L1
        proposal_data: ProposalContent,  # from L1 blobs
        protocol_state: ProtoState,  # from L2
        parent_block_header: BlockHeaderPartial,  # from L2
        parent_block_hash: HexStr,  # from L2
        i: int  # the i-th block in the list
    ) -> BlockInput:
        """
        Compile input parameters for building a block.
        
        Args:
            proposal: The proposal from L1
            reference_block_header: Reference block header from L1
            proposal_data: Decoded proposal data from L1 blobs
            protocol_state: Current protocol state from L2
            parent_block_header: Parent block header from L2
            parent_block_hash: Hash of the parent block from L2
            i: Index of the block to build in the proposal
            
        Returns:
            BlockInput: Compiled input for building the block
            
        Raises:
            ValueError: If block index is invalid
        """
        if i >= len(proposal_data.blocks):
            raise ValueError("Invalid block index")
        
        blk = proposal_data.blocks[i]
        
        # Initialize gas issuance for first block
        if i == 0:
            if protocol_state.gas_issuance_per_second == 0:
                protocol_state.gas_issuance_per_second = self.DEFAULT_GAS_ISSUANCE_PER_SECOND
        
        # Use provided parent hash directly
        parent_hash = parent_block_hash
        number = parent_block_header.number + 1
        
        # Timestamp calculations with constraints
        timestamp = max(blk.timestamp, parent_block_header.timestamp + self.MIN_L2_BLOCK_TIME)
        timestamp = min(timestamp, reference_block_header.timestamp + self.L1_BLOCK_TIME)
        timestamp = min(timestamp, reference_block_header.timestamp + self.MAX_BLOCK_TIMESTAMP_OFFSET)
        
        # Update block timestamp
        blk.timestamp = timestamp
        
        # Gas calculations based on block time
        block_time = timestamp - parent_block_header.timestamp
        gas_issuance = block_time * protocol_state.gas_issuance_per_second
        gas_limit = gas_issuance * 2
        
        # Determine fee recipient
        fee_recipient = (
            proposal.proposer if blk.fee_recipient == '0x0000000000000000000000000000000000000000'
            else blk.fee_recipient
        )
        
        # Compute prevRandao using keccak256 equivalent
        prev_randao = self._compute_prev_randao(number, reference_block_header.prevRandao)
        
        extra_data = i

        base_fee_per_gas = self._compute_base_fee_per_gas(timestamp - parent_block_header.timestamp, protocol_state)
        
        # Note: Gas issuance update logic for last block is commented out in the original
        # If needed, it would be implemented here:
        # if i == len(proposal_data.blocks) - 1:
        #     if proposal_data.gas_issuance_per_second != 0:
        #         max_allowed = protocol_state.gas_issuance_per_second * self.GAS_ISSUANCE_PER_SECOND_MAX_OFFSET
        #         min_allowed = protocol_state.gas_issuance_per_second * self.GAS_ISSUANCE_PER_SECOND_MIN_OFFSET
        #         v = proposal_data.gas_issuance_per_second * 100
        #         
        #         if min_allowed <= v <= max_allowed:
        #             protocol_state.gas_issuance_per_second = proposal_data.gas_issuance_per_second
        
        return BlockInput(
            timestamp=timestamp,
            parent_hash=parent_hash,
            fee_recipient=fee_recipient,
            number=number,
            gas_limit=gas_limit,
            prev_randao=prev_randao,
            base_fee_per_gas=base_fee_per_gas,
            extra_data=extra_data,
            block_count=len(proposal_data.blocks),
            transactions=blk.transactions
        )
    
    def _compute_base_fee_per_gas(self, block_time: int, protocol_state: ProtoState) -> int:
        """
        Compute the base fee per gas for the block.
        
        This is a mock implementation. In a real system, this would implement
        EIP-4396 style base fee calculation based on network congestion.
        
        Args:
            block_time: Time elapsed since parent block
            protocol_state: Current protocol state
            
        Returns:
            int: Base fee per gas 
        """
        raise NotImplementedError("Must be implemented by node")   
    
    def _compute_prev_randao(self, number: int, reference_prev_randao: HexStr) -> HexStr:
        """
        Compute prevRandao value using keccak256 equivalent.
        
        In Solidity: keccak256(abi.encode(number, prevRandao))
        """
        # Using SHA256 as a substitute for keccak256 in this demo
        data = f"{number}{reference_prev_randao}".encode()
        return '0x' + hashlib.sha256(data).hexdigest()