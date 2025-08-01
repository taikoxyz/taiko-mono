from dataclasses import dataclass
from typing import List
from eth_typing import Address, HexStr


## --- Onchain ---
@dataclass
class BlobSegment:
    """Represents a blob segment from IShastaInbox."""

    blobHashes: List[HexStr]  # bytes32[] in Solidity
    offset: int  # uint32 in Solidity
    size: int  # uint32 in Solidity


@dataclass
class Proposal:
    """Represents a proposal from IShastaInbox."""

    id: int  # uint48 in Solidity
    proposer: Address
    prover: Address
    provability_bond: int  # uint48 in Solidity
    liveness_bond: int  # uint48 in Solidity
    reference_block_timestamp: int  # uint48 in Solidity
    reference_block_number: int  # uint48 in Solidity
    reference_block_hash: HexStr  # bytes32 in Solidity
    content: BlobSegment


## --- Offchain  ---
@dataclass
class BlockHeaderPartial:
    """Partial representation of LibBlockHeader.BlockHeader with only fields used in building new blocs"""

    number: int
    timestamp: int
    prevRandao: HexStr


@dataclass
class Transaction:
    """Represents a transaction in the system."""

    to: Address
    value: int
    data: bytes
    signature: bytes


@dataclass
class BlockArgs:
    """Represents a block with transactions."""

    timestamp: int
    fee_recipient: Address
    anchor_block_number: int
    transactions: List[Transaction]


@dataclass
class Content:
    """Data associated with a proposal."""

    gas_issuance_per_second: int
    block_argss: List[BlockArgs]


@dataclass
class ProtoState:
    """Current state of the protocol."""

    proposal_id: int
    block_index: int
    gas_issuance_per_second: int
    gas_excess: int
    anchor_block_height: int
    anchor_block_hash: HexStr
