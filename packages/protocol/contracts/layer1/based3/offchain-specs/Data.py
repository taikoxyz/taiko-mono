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
    provabilityBond: int  # uint48 in Solidity
    livenessBond: int  # uint48 in Solidity
    proposedAt: int  # uint48 in Solidity
    referenceBlockHash: HexStr  # bytes32 in Solidity
    content: BlobSegment

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
    anchorBlockHeight: int ## TODO?????

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
    anchor_block_height: int    
    anchor_block_hash: HexStr

@dataclass
class BlockInput:
    """Input parameters for building a block."""
    parent_block_hash: HexStr
    proposal: Proposal
    block_index: int
    timestamp: int
    parent_hash: HexStr
    fee_recipient: Address
    number: int
    gas_limit: int
    prev_randao: HexStr
    base_fee_per_gas: int
    block_count: int
    anchor_block_height: int
    anchor_block_hash: HexStr
    transactions: List[Transaction]

