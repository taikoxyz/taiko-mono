from dataclasses import dataclass
from typing import List, Optional
from eth_typing import Address, HexStr

@dataclass
class BlockHeaderPartial:
    """Partial representation of LibBlockHeader.BlockHeader with only fields used in building new blocs"""
    number: int
    timestamp: int
    prevRandao: HexStr

@dataclass
class Proposal:
    """Represents a proposal from IShastaInbox."""
    proposer: Address
    proposedAt: int  # uint48 in Solidity
    id: int  # uint48 in Solidity
    latestL1BlockHash: HexStr  # bytes32 in Solidity
    blobDataHash: HexStr  # bytes32 in Solidity
    livenessBond: int

@dataclass
class Transaction:
    """Represents a transaction in the system."""
    to: Address
    value: int
    data: bytes
    signature: bytes

@dataclass
class Block:
    """Represents a block with transactions."""
    timestamp: int
    fee_recipient: Address
    transactions: List[Transaction]

@dataclass
class ProposalData:
    """Data associated with a proposal."""
    gas_issuance_per_second: int
    blocks: List[Block]

@dataclass
class ProtocolState:
    """Current state of the protocol."""
    gas_issuance_per_second: int
    gas_excess: int
    designated_proposer: Address

@dataclass
class BlockInput:
    """Input parameters for building a block."""
    timestamp: int
    parent_hash: HexStr
    fee_recipient: Address
    number: int
    gas_limit: int
    prev_randao: HexStr
    base_fee_per_gas: int
    extra_data: int
    block_count: int
    transactions: List[Transaction]

