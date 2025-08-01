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
    
    def block_head_call(
        self,
        protocol_state: ProtocolState,
        block_input: BlockInput
    ) -> None:
        """
        System call invoked before the the first transaction in every block.
        This call does not consume gas.
        """
        assert protocol_state == self.load_protocol_state()

        # The following code runs only once per proposal at the very beginning
        if block_input.block_index == 0:
            # what should be done here?
            pass

        if block_input.anchor_block_height > protocol_state.anchor_block_height and block_input.anchor_block_hash !=0:
            protocol_state.anchor_block_height = block_input.anchor_block_height
            protocol_state.anchor_block_hash = block_input.anchor_block_hash    
        
        self.save_protocol_state(protocol_state)

           

    def block_tail_call(
        self,
        protocol_state: ProtocolState,
        block_input: BlockInput,
        gas_used: int,
        parent_block_timestmap:int
    ) -> None:
        """
        System call invoked after the last transaction in every block.
        This call does not consume gas.
        """ 
        assert protocol_state == self.load_protocol_state()

        # update base fee parameters
        block_time = block_input.timestamp - parent_block_timestmap
        gas_issuance = protocol_state.gas_issuance_per_second * block_time
        protocol_state.gas_excess += gas_issuance
        protocol_state.gas_excess -= gas_used
        if protocol_state.gas_excess < 0:
            protocol_state.gas_excess = 0

        # the following code runs only once per proposal at the very end
        if block_input.block_index == block_input.block_count - 1:
            protocol_state.gas_issuance_per_second = block_input.gas_issuance_per_second / 100

        self.save_protocol_state(protocol_state)
    