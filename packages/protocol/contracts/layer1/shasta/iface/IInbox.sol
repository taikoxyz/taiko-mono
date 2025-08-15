// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title IInbox
/// @notice Interface for the ShastaInbox contract
/// @custom:security-contact security@taiko.xyz
interface IInbox {
    /// @notice Configuration parameters for the Inbox contract
    struct Config {
        address bondToken;
        uint48 provingWindow;
        uint48 extendedProvingWindow;
        uint256 maxFinalizationCount;
        uint256 ringBufferSize;
        uint8 basefeeSharingPctg;
        address syncedBlockManager;
        address proofVerifier;
        address proposerChecker;
        address forcedInclusionStore;
    }

    /// @notice Represents a proposal for L2 blocks.
    struct Proposal {
        /// @notice Unique identifier for the proposal.
        uint48 id;
        /// @notice Address of the proposer.
        address proposer;
        /// @notice The L1 block timestamp when the proposal was accepted.
        uint48 originTimestamp;
        /// @notice The L1 block number when the proposal was accepted.
        uint48 originBlockNumber;
        /// @notice Whether the proposal is from a forced inclusion.
        bool isForcedInclusion;
        /// @notice The percentage of base fee paid to coinbase.
        uint8 basefeeSharingPctg;
        /// @notice Blobs that contains the proposal's manifest data.
        LibBlobs.BlobSlice blobSlice;
        /// @notice The current hash of coreState
        bytes32 coreStateHash;
    }

    /// @notice Represents a claim about the state transition of a proposal.
    struct Claim {
        /// @notice The proposal's hash.
        bytes32 proposalHash;
        /// @notice The parent claim's hash, this is used to link the claim to its parent claim to
        /// finalize the corresponding proposal.
        bytes32 parentClaimHash;
        /// @notice The block number for the end (last) L2 block in this proposal.
        uint48 endBlockNumber;
        /// @notice The block hash for the end (last) L2 block in this proposal.
        bytes32 endBlockHash;
        /// @notice The state root for the end (last) L2 block in this proposal.
        bytes32 endStateRoot;
        /// @notice The designated prover.
        address designatedProver;
        /// @notice The actual prover.
        address actualProver;
    }

    /// @notice Represents a record of a claim with additional metadata.
    struct ClaimRecord {
        /// @notice The proposal's ID.
        uint48 proposalId;
        /// @notice The claim.
        Claim claim;
        /// @notice The span indicating how many proposals this claim record covers.
        uint8 span;
        /// @notice The bond instructions.
        LibBonds.BondInstruction[] bondInstructions;
    }

    /// @notice Represents the core state of the inbox.
    struct CoreState {
        /// @notice The next proposal ID to be assigned.
        uint48 nextProposalId;
        /// @notice The ID of the last finalized proposal.
        uint48 lastFinalizedProposalId;
        /// @notice The hash of the last finalized claim.
        bytes32 lastFinalizedClaimHash;
        /// @notice The hash of all bond instructions.
        bytes32 bondInstructionsHash;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed.
    /// @param data The encoded (Proposal, CoreState)
    event Proposed(bytes data);

    /// @notice Emitted when a proof is submitted
    /// @param data The encoded ClaimRecord
    event Proved(bytes data);

    /// @notice Emitted when bond instructions are issued
    /// @param instructions The bond instructions that need to be performed.
    event BondInstructed(LibBonds.BondInstruction[] instructions);

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Proposes new proposals of L2 blocks.
    /// @param _lookahead The data to post a new lookahead (currently unused).
    /// @param _data The data containing the core state, blob locator, and claim records.
    function propose(bytes calldata _lookahead, bytes calldata _data) external;

    /// @notice Proves a claim about some properties of a proposal, including its state transition.
    /// @param _data The data containing the proposals and claims to be proven.
    /// @param _proof Validity proof for the claims.
    function prove(bytes calldata _data, bytes calldata _proof) external;

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @notice Fetches the values of specified settings to assist in aligning off-chain
    /// software configurations.
    /// @dev To minimize frequent queries for new values, these settings should only update at
    /// specific time unit boundaries, such as daily at midnight GMT:
    /// ```
    /// require(itemChangeTimestamp % 86400 == 0);
    /// return (block.timestamp >= itemChangeTimestamp) ? itemNewValue : itemOldValue;
    /// ```
    /// @param _names An array of identifiers for the settings to be fetched.
    /// @return values_ An array containing the values corresponding to the specified settings. If a
    /// name is invalid, bytes32(0) will be returned without reverting.
    function getNamedSettings(bytes32[] memory _names)
        external
        view
        returns (bytes32[] memory values_);

    /// @notice Returns the capacity for unfinalized proposals.
    /// @return _ The maximum number of unfinalized proposals that can exist.
    function getCapacity() external view returns (uint256);

    /// @notice Returns the configuration parameters for the Inbox contract.
    /// @return config_ The configuration parameters.
    function getConfig() external view returns (Config memory config_);
}
