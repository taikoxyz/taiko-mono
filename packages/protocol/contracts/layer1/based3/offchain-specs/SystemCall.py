from typing import Optional, Dict, Any
from Data import ProtocolState, BlockInput, ProposalData, Proposal


class SystemCall:
    """
    Handles system calls that execute at the beginning and end of block processing.
    These calls do not consume gas and are used for protocol-level operations.
    """
    
    MIN_TAIKO_BALANCE = 10000 * 10**18
    GAS_ISSUANCE_PER_SECOND_MAX_OFFSET = 101
    GAS_ISSUANCE_PER_SECOND_MIN_OFFSET = 99
    
    def load_protocol_state(self) -> ProtocolState:
        """
        Load the current protocol state from storage.
        This function retrieves the protocol state that persists across blocks.
        """
        raise NotImplementedError("Must be implemented by execution layer")
    
    def save_protocol_state(self, protocol_state: ProtocolState) -> None:
        """
        Save the protocol state to storage.
        This function persists the protocol state for future blocks.
        """
        raise NotImplementedError("Must be implemented by execution layer")
    
    def head_system_call(
        self,
        proposal: Proposal,
        block_input: BlockInput,
        protocol_state: ProtocolState
    ) -> None:
        """
        Execute system operations before processing the first transaction in a block.
        This call does not consume gas.
        """
       
    def tail_system_call(
        self,
        block_input: BlockInput,
        proposal_data: ProposalData,
        protocol_state: ProtocolState,
        gas_used: int
    ) -> None:
        """
        Execute system operations after processing all transactions in a block.
        This call does not consume gas.
        """

        if block_input.block_count == block_input.extra_data + 1:
            if proposal_data.gas_issuance_per_second != 0:
                max_allowed = protocol_state.gas_issuance_per_second * self.GAS_ISSUANCE_PER_SECOND_MAX_OFFSET
                min_allowed = protocol_state.gas_issuance_per_second * self.GAS_ISSUANCE_PER_SECOND_MIN_OFFSET
                v = proposal_data.gas_issuance_per_second * 100
                
                if min_allowed <= v <= max_allowed:
                    protocol_state.gas_issuance_per_second = proposal_data.gas_issuance_per_second

        protocol_state.gas_excess -= gas_used  
        self.save_protocol_state(protocol_state)
        
    