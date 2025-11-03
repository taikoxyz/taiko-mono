// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibManifest
/// @custom:security-contact security@taiko.xyz
library LibManifest {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Represents a signed Ethereum transaction
    /// @dev Follows EIP-2718 typed transaction format with EIP-1559 support
    struct SignedTransaction {
        uint8 txType;
        uint64 chainId;
        uint64 nonce;
        uint256 maxPriorityFeePerGas;
        uint256 maxFeePerGas;
        uint64 gasLimit;
        address to;
        uint256 value;
        bytes data;
        bytes accessList;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @notice Represents a block manifest
    struct BlockManifest {
        /// @notice The timestamp of the block.
        uint48 timestamp;
        /// @notice The coinbase of the block.
        address coinbase;
        /// @notice The anchor block number. This field can be zero, if so, this block will use the
        /// most recent anchor in a previous block.
        uint48 anchorBlockNumber;
        /// @notice The block's gas limit.
        uint48 gasLimit;
        /// @notice The transactions for this block.
        SignedTransaction[] transactions;
    }

    /// @notice Represents a proposal manifest containing proposal-level metadata and all sources
    /// @dev The ProposalManifest aggregates all DerivationSources' blob data for a proposal.
    /// The proverAuthBytes is proposal-level (one designated prover per proposal), while the
    /// sources array contains per-source block data.
    struct ProposalManifest {
        /// @notice Prover authentication data (proposal-level, shared across all sources).
        bytes proverAuthBytes;
        /// @notice Array of derivation source manifests (one per DerivationSource).
        DerivationSourceManifest[] sources;
    }

    /// @notice Represents a derivation source manifest containing blocks for one source
    /// @dev Each proposal can have multiple DerivationSourceManifests (one per DerivationSource).
    /// If a DerivationSourceManifest is invalid, it is replaced with a default manifest
    /// (single block with only an anchor transaction), but the entire proposal is NOT invalidated.
    /// This design prevents
    /// censorship of forced inclusions: a malicious proposer cannot invalidate their entire
    /// proposal (including valid forced inclusions) by including bad data in one source.
    struct DerivationSourceManifest {
        /// @notice The blocks for this derivation source.
        BlockManifest[] blocks;
    }
}
