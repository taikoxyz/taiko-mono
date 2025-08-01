from typing import Optional, Dict, Any, Tuple, cast
from eth_typing import HexStr, Address
import hashlib
from IShasta import ProtoState, BlockArgs, Content, Proposal


class BlockCalls:
    """
    Handles system calls that execute at the beginning and end of block processing.
    These calls do not consume gas and are used for protocol-level operations.
    """

    MIN_TAIKO_BALANCE = 10000 * 10**18
    DEFAULT_GAS_ISSUANCE_PER_SECOND = 1_000_000
    GAS_ISSUANCE_PER_SECOND_MAX_OFFSET = 101
    GAS_ISSUANCE_PER_SECOND_MIN_OFFSET = 99
    ADDRESS_ZERO = "0x0000000000000000000000000000000000000000"
    BLOCK_GAS_LIMIT = 100_000_000
    TAIKO_DAO_TREASURE = "0x0000000000000000000000000000000000000123"

    def block_head_call(
        self,
        proposal: Proposal,
        proto_state: ProtoState,
        block_args: BlockArgs,
        block_number: int,
        parent_prev_randao: HexStr,
        parent_timestamp: int,
        reference_block_timestamp: int,
        reference_block_number: int,
        anchor_block_hash: HexStr,
    ) -> Tuple[int, HexStr, Address, int, int]:
        """
        System call invoked before the the first transaction in every block.
        This call does not consume gas.

        Returns:
            - timestamp
            - prevRandao
            - fee recipient
            - gas limit
            - extra data
        """
        timestamp = max(
            min(block_args.timestamp, reference_block_timestamp),
            parent_timestamp,
            reference_block_timestamp - 128,
        )

        extra_data = 0
        gas_limit = self.BLOCK_GAS_LIMIT
        prev_randao = self._calculate_prev_randao(block_number, parent_prev_randao)
        fee_recipient = self._caculate_fee_recipient(block_args.fee_recipient)

        proto_state.anchor_block_height, proto_state.anchor_block_hash = (
            self._calculate_anchor(
                proto_state, block_args, reference_block_number, anchor_block_hash
            )
        )

        self._save_proto_state(proto_state)

        return (timestamp, prev_randao, fee_recipient, gas_limit, extra_data)

    def block_tail_call(
        self,
        proto_state: ProtoState,
        block_args: BlockArgs,
        block_index: int,
        batch_size: int,
        gas_used: int,
        timestamp: int,
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
        if block_index == batch_size - 1:
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
        if fee_recipient == self.ADDRESS_ZERO:
            return cast(Address, self.TAIKO_DAO_TREASURE)
        else:
            return fee_recipient

    def _save_proto_state(self, proto_state: ProtoState) -> None:
        """
        Save the protocol state to storage.
        This function persists the protocol state for future blocks.
        """
        raise NotImplementedError("Must be implemented by execution layer")
