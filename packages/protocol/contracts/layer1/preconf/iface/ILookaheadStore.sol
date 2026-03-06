// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";

/// @title ILookaheadStore
/// @custom:security-contact security@taiko.xyz
interface ILookaheadStore {
    // ---------------------------------------------------------------
    // Lookahead structs
    // ---------------------------------------------------------------

    /// @dev An array of `LookaheadSlot` structs is encoded using `LibLookaheadEncoder`
    /// and its keccak-hash is stored
    struct LookaheadSlot {
        // The preconfer operator's committer address that is fetched from the slashing commitment.
        address committer;
        // Timestamp of the slot.
        uint48 timestamp;
        // Index of the Operator's registration merkle tree leaf that contains the validator for the
        // slot.
        uint16 validatorLeafIndex;
        // URC registration root of the operator
        bytes32 registrationRoot;
    }

    struct LookaheadHash {
        // The timestamp of the epoch.
        uint48 epochTimestamp;
        // Keccak hash of the lookahead slots for the epoch.
        bytes26 lookaheadHash;
    }

    struct LookaheadData {
        /// @notice Index of the slot of the proposer in the current lookahead.
        /// @dev Must be set to type(uint256).max if the proposer is from the next epoch
        uint256 slotIndex;
        /// @notice Current epoch lookahead slots. It is only used for validation
        /// @dev LibLookaheadEncoder encoded `LookaheadSlot[]` array
        /// @dev Must be provided exactly as originally posted
        bytes currLookahead;
        /// @notice Next epoch lookahead slots. If there's no lookahead stored for next epoch, it
        /// will be updated with this value
        /// @dev LibLookaheadEncoder encoded `LookaheadSlot[]` array
        /// @dev Can be empty for same-epoch proposers when next epoch lookahead already exists
        /// on-chain (gas optimization). Must be provided for cross-epoch proposers (need slot
        /// info) and fallback preconfers (responsible for posting/validation)
        bytes nextLookahead;
        /// @notice Commitment signature for the next lookahead
        /// @dev Must be set to an empty bytes if the lookahead for the next epoch is already
        // posted or the preconfer is a whitelisted preconfer
        bytes commitmentSignature;
    }

    struct ProposerContext {
        // `True` if the expected proposer is the fallback preconfer
        bool isFallback;
        // Address of the expected proposer (opted-in or fallback)
        address proposer;
        // Starting timestamp of the preconfing window
        uint256 submissionWindowStart;
        // Ending timestamp of the preconfing window
        uint256 submissionWindowEnd;
        // The lookahead slot covering the current preconfing window
        LookaheadSlot lookaheadSlot;
    }

    // ---------------------------------------------------------------
    // Blacklist structs
    // ---------------------------------------------------------------

    struct BlacklistTimestamps {
        uint48 blacklistedAt;
        uint48 unBlacklistedAt;
    }

    /// @dev These delays prevent lookahead state from changing mid-epoch.
    /// We do not store historical blacklist data. If an operator is blacklisted,
    /// then unblacklisted, and blacklisted again within a single lookahead window,
    /// we cannot determine when the first blacklist occurred (without storing full
    /// history). Therefore, we cannot slash a lookahead poster for failing to include
    /// a non-blacklisted preconfer.
    struct BlacklistConfig {
        // Delay after which a formerly unblacklisted operator can be blacklisted again
        uint256 blacklistDelay;
        // Delay after which a formerly blacklisted operator can be unblacklisted again
        uint256 unblacklistDelay;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event LookaheadPosted(uint256 indexed epochTimestamp, bytes26 lookaheadHash);
    event Blacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);
    event Unblacklisted(bytes32 indexed operatorRegistrationRoot, uint48 timestamp);
    event OverseerSet(address indexed oldOverseer, address indexed newOverseer);

    // ---------------------------------------------------------------
    // Lookahead functions
    // ---------------------------------------------------------------

    /// @notice Returns the proposer context for the given lookahead input and epoch.
    /// @dev Useful for off-chain nodes to determine the next proposer/preconfer.
    /// @param _epochTimestamp The timestamp of the proposer's epoch.
    /// @param _data The lookahead data for the proposer's epoch, plus the next epoch.
    /// @return context_ The proposer context, including the proposer and submission window bounds.
    function getProposerContext(
        uint256 _epochTimestamp,
        LookaheadData calldata _data
    )
        external
        view
        returns (ProposerContext memory context_);

    /// @notice Returns true if the lookahead is required for the next epoch.
    /// @return True if the lookahead is required for the next epoch, false otherwise.
    function isLookaheadRequired() external view returns (bool);

    /// @notice Builds a lookahead commitment for use with the URC slasher.
    /// @param _epochTimestamp The timestamp of the epoch.
    /// @param _encodedLookahead The encoded lookahead bytes.
    /// @return The slasher commitment.
    function buildLookaheadCommitment(
        uint256 _epochTimestamp,
        bytes calldata _encodedLookahead
    )
        external
        view
        returns (ISlasher.Commitment memory);

    /// @notice Calculates the lookahead hash for a given epoch and encoded lookahead.
    /// @param _epochTimestamp The timestamp of the epoch.
    /// @param _encodedLookahead The encoded lookahead bytes.
    /// @return The lookahead hash.
    function calculateLookaheadHash(
        uint256 _epochTimestamp,
        bytes calldata _encodedLookahead
    )
        external
        pure
        returns (bytes26);

    /// @notice Encodes an array of lookahead slots into the compact binary format
    /// used by the lookahead store.
    /// @param _lookaheadSlots The array of lookahead slots to encode.
    /// @return The encoded lookahead bytes.
    function encodeLookahead(LookaheadSlot[] calldata _lookaheadSlots)
        external
        pure
        returns (bytes memory);

    /// @notice Returns the lookahead hash for an epoch.
    /// @param _epochTimestamp The timestamp of the epoch.
    /// @return The lookahead hash. If the epoch is not found, returns 0.
    function getLookaheadHash(uint256 _epochTimestamp) external view returns (bytes26);

    // ---------------------------------------------------------------
    // Blacklist functions
    // ---------------------------------------------------------------

    /// @notice Sets the overseer address that can blacklist/unblacklist operators.
    /// @param _newOverseer The new overseer address.
    function setOverseer(address _newOverseer) external;

    /// @notice Blacklists a preconf operator for subjective faults.
    /// @param _operatorRegistrationRoot Registration root of the operator being blacklisted.
    function blacklistOperator(bytes32 _operatorRegistrationRoot) external;

    /// @notice Removes an operator from the blacklist.
    /// @param _operatorRegistrationRoot Registration root of the operator to unblacklist.
    function unblacklistOperator(bytes32 _operatorRegistrationRoot) external;

    /// @notice Returns the blacklist configuration with delay parameters.
    /// @return The blacklist configuration.
    function getBlacklistConfig() external pure returns (BlacklistConfig memory);

    /// @notice Returns the blacklist timestamps for an operator.
    /// @param _operatorRegistrationRoot Registration root of the operator.
    /// @return The blacklist timestamps containing blacklist and unblacklist timestamps.
    function getBlacklist(bytes32 _operatorRegistrationRoot)
        external
        view
        returns (BlacklistTimestamps memory);

    /// @notice Checks if an operator is currently blacklisted.
    /// @param _operatorRegistrationRoot Registration root of the operator.
    /// @return True if the operator is blacklisted, false otherwise.
    function isOperatorBlacklisted(bytes32 _operatorRegistrationRoot) external view returns (bool);
}
