from typing import Tuple, cast, List
from eth_typing import HexStr, Address
import hashlib
from eth_account import Account
from eth_utils import keccak
from Types import ProtoState, BlockArgs, Proposal, Content


class BlockCalls:
    """
    Handles system calls that execute at the beginning and end of block processing.
    These calls do not consume gas and are used for protocol-level operations.
    """

    DEFAULT_GAS_ISSUANCE_PER_SECOND = 1_000_000
    GAS_ISSUANCE_PER_SECOND_MAX_OFFSET = 101
    GAS_ISSUANCE_PER_SECOND_MIN_OFFSET = 99
    ADDRESS_ZERO = cast(Address, "0x0000000000000000000000000000000000000000")
    BLOCK_GAS_LIMIT = 100_000_000
    TAIKO_DAO_TREASURE = cast(Address, "0x0000000000000000000000000000000000000123")

    def block_head_call(
        self,
        # provable: -> parent_block_hash
        proto_state: ProtoState,
        # provable: -> proposal_hash
        proposal: Proposal,
        # provable: -> proposal_hash
        proposal_content: Content,
        # provable: -> content -> proposal_hash
        block_args: BlockArgs,
        # provable: -> parent_block_number -> parent_block_hash
        block_number: int,
        # provable: -> parent_block_hash
        parent_prev_randao: HexStr,
        # provable: -> parent_block_hash
        parent_timestamp: int,
        # provable: -> up to 128 ancester block headers -> anchor_block_hash
        anchor_block_hash: HexStr,
        bond_credit_ops: List[Tuple[Address, int]],
    ) -> Tuple[int, HexStr, Address, int, int]:
        """
        System call invoked before the the first transaction in every block.
        This call does not consume gas.

        Returns:
            - timestamp
            - prev_randao
            - fee_recipient
            - gas_limit
            - extra_data
            - designated_prover
        """

        if proto_state.proposal_id != proposal.id:
            assert proto_state.proposal_id + 1 == proposal.id, "proposal_id mismatch"
            assert proto_state.block_index != 0, "block_index mismatch"

            proto_state.proposal_id = proposal.id
            proto_state.block_index = 0

            proto_state.designated_prover = self._calculate_designated_prover(proposal, proposal_content)



            for bond_credit_op in bond_credit_ops:
                bond_balance = self._get_bond_balance(bond_credit_op[0])
                bond_balance += bond_credit_op[1]
                self._save_bond_balance(bond_credit_op[0], bond_balance)
                proto_state.bond_credits_hash = self._aggregate_bond_credits(proto_state.bond_credits_hash, bond_credit_op[0], bond_credit_op[1])
                
            assert proto_state.bond_credits_hash == proposal.bond_credit_hash, "bond_credits_hash mismatch"

        timestamp = max(
            parent_timestamp,
            proposal.reference_block_timestamp - 128,
            min(block_args.timestamp, proposal.reference_block_timestamp),
        )

        extra_data = 0
        gas_limit = self.BLOCK_GAS_LIMIT
        prev_randao = self._calculate_prev_randao(block_number, parent_prev_randao)
        fee_recipient = self._caculate_fee_recipient(block_args.fee_recipient)

        proto_state.anchor_block_height, proto_state.anchor_block_hash = (
            self._calculate_anchor(
                proto_state,
                block_args,
                proposal.reference_block_number,
                anchor_block_hash,
            )
        )

        self._save_proto_state(proto_state)

        return (timestamp, prev_randao, fee_recipient, gas_limit, extra_data)

    def block_tail_call(
        self,
        # provable: -> parent_block_hash
        proto_state: ProtoState,
        # provable: -> content -> proposal_hash
        batch_size: int,
        # provable: -> EVM Code
        gas_used: int,
        # proverabel: same value as in block_head_call
        timestamp: int,
        # proverabel: same value as in block_head_call
        parent_timestamp: int,
    ) -> None:
        """
        System call invoked after the last transaction in every block.
        This call does not consume gas.
        """

        # update base fee parameters
        proto_state.gas_excess = self._calculate_gas_excess(
            proto_state.gas_excess,
            proto_state.gas_issuance_per_second,
            timestamp - parent_timestamp,
            gas_used,
        )

        # the following code runs only once per proposal at the very end
        if proto_state.block_index == batch_size - 1:
            proto_state.gas_issuance_per_second = (
                self._calculate_gas_issuance_per_second(
                    proto_state.gas_issuance_per_second,
                    proto_state.gas_issuance_per_second,
                )
            )

        self._save_proto_state(proto_state)

    def _calculate_prev_randao(self, number: int, parent_prev_randao: HexStr) -> HexStr:
        """
        Compute prevRandao value using keccak256 equivalent.
        In Solidity: keccak256(abi.encode(number, prevRandao))
        """
        data = f"{number}{parent_prev_randao}".encode()
        return cast(HexStr, "0x" + hashlib.sha256(data).hexdigest())

    def _calculate_gas_excess(
        self,
        current_gas_excess: int,
        current_gas_issuance_per_second: int,
        block_time: int,
        gas_used: int,
    ) -> int:
        """
        Calculate gas excess
        """
        if current_gas_issuance_per_second == 0:
            current_gas_issuance_per_second = self.DEFAULT_GAS_ISSUANCE_PER_SECOND

        gas_issuance = current_gas_issuance_per_second * block_time
        return max(current_gas_excess + gas_issuance - gas_used, 0)

    def _calculate_gas_issuance_per_second(
        self, current_gas_issuance_per_second: int, new_gas_issuance_per_second: int
    ) -> int:
        """
        Calculate gas issuance per second
        """
        if new_gas_issuance_per_second == 0:
            return current_gas_issuance_per_second

        min = (
            current_gas_issuance_per_second
            * self.GAS_ISSUANCE_PER_SECOND_MIN_OFFSET
            / 100
        )
        max = (
            current_gas_issuance_per_second
            * self.GAS_ISSUANCE_PER_SECOND_MAX_OFFSET
            / 100
        )

        if min <= new_gas_issuance_per_second <= max:
            return new_gas_issuance_per_second
        else:
            return current_gas_issuance_per_second

    def _calculate_anchor(
        self,
        proto_state: ProtoState,
        block_args: BlockArgs,
        reference_block_number: int,
        anchor_block_hash: HexStr,
    ) -> Tuple[int, HexStr]:
        """
        Calculate and update anchor block if conditions are met.
        """
        if (
            block_args.anchor_block_number > proto_state.anchor_block_height
            and block_args.anchor_block_number >= reference_block_number - 64
            and block_args.anchor_block_number < reference_block_number
        ):
            return (block_args.anchor_block_number, anchor_block_hash)
        else:
            return (proto_state.anchor_block_height, proto_state.anchor_block_hash)

    def _caculate_fee_recipient(self, fee_recipient: Address) -> Address:
        """
        Calculate fee recipient
        """
        if fee_recipient ==  self.ADDRESS_ZERO:
            return self.TAIKO_DAO_TREASURE
        else:
            return fee_recipient


    def _calculate_designated_prover(self, proposal: Proposal, proposal_content: Content) -> Address:
        """
        Calculate the designated prover for the proposal
        """
        # Recover prover address from signature
        try:
            # Create hash of proposal data
            proposal_data = (
                proposal.id.to_bytes(6, 'big') +  # uint48
                bytes.fromhex(proposal.proposer[2:]) +  # address
                proposal.liveness_bond.to_bytes(6, 'big') +  # uint48
            )
            
            # Hash the proposal data using keccak256
            message_hash = keccak(proposal_data)
            
            # Recover the address from the signature
            account = Account.recover_message(message_hash, signature=proposal_content.prover_signature)
            prover = cast(Address, account)
        except Exception:
            # If signature recovery fails, use zero address
            prover =  self.ADDRESS_ZERO
            
        if prover == self.ADDRESS_ZERO or prover == proposal.proposer:
            return proposal.proposer

        if proposal.liveness_bond > 0:
            prover_bond_balance = self._get_bond_balance(prover)
            if (prover_bond_balance < proposal.liveness_bond):
                return proposal.proposer
        
        if proposal_content.prover_fee > 0:
            proposer_bond_balance = self._get_bond_balance(proposal.proposer)
            if (proposer_bond_balance < proposal_content.prover_fee):
                return proposal.proposer
        
        prover_bond_balance +=  proposal_content.prover_fee
        prover_bond_balance -= proposal.liveness_bond
        self._save_bond_balance(prover, prover_bond_balance)

        proposer_bond_balance -= proposal_content.prover_fee
        self._save_bond_balance(proposal.proposer, proposer_bond_balance)

        return prover

    def _aggregate_bond_credits(self, bond_credits_hash: HexStr, account: Address, bond: int) -> HexStr:
        """
        Aggregate the bond credits
        """
        # Convert bond_credits_hash from HexStr to bytes if needed
        if isinstance(bond_credits_hash, str):
            if bond_credits_hash.startswith('0x'):
                bond_credits_hash_bytes = bytes.fromhex(bond_credits_hash[2:])
            else:
                bond_credits_hash_bytes = bytes.fromhex(bond_credits_hash)
        else:
            bond_credits_hash_bytes = bond_credits_hash
            
        # Convert address to bytes (20 bytes)
        if isinstance(account, str):
            if account.startswith('0x'):
                account_bytes = bytes.fromhex(account[2:])
            else:
                account_bytes = bytes.fromhex(account)
        else:
            account_bytes = account
            
        # Ensure address is 20 bytes (pad with zeros if needed)
        account_bytes = account_bytes.rjust(20, b'\x00')
        
        # Convert bond (uint48) to bytes (6 bytes)
        bond_bytes = bond.to_bytes(6, byteorder='big')
        
        # ABI encode: bytes32 + address (20 bytes padded to 32) + uint48 (6 bytes padded to 32)
        # Following Solidity's abi.encode rules
        encoded_data = (
            bond_credits_hash_bytes.rjust(32, b'\x00') +  # bytes32
            account_bytes.rjust(32, b'\x00') +            # address padded to 32 bytes
            bond_bytes.rjust(32, b'\x00')                 # uint48 padded to 32 bytes
        )
        
        # Calculate keccak256 hash
        new_hash = keccak(encoded_data)
        
        # Return as HexStr
        return HexStr('0x' + new_hash.hex())

    def _save_proto_state(self, proto_state: ProtoState) -> None:
        """
        Save the protocol state to storage.
        This function persists the protocol state for future blocks.
        """
        raise NotImplementedError("Must be implemented by execution layer")

    def _get_bond_balance(self, address: Address) -> int:
        """
        Get the bond balance for the address
        """
        raise NotImplementedError("Must be implemented by execution layer")

    def _save_bond_balance(self, address: Address, balance: int) -> None:
        """
        Save the bond balance for the address
        """
        raise NotImplementedError("Must be implemented by execution layer")