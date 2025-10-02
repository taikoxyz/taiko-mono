// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@eth-fabric/urc/ISlasher.sol";

/// @title ILookaheadStore
/// @custom:security-contact security@taiko.xyz
interface ILookaheadStore {
    // An array of LookaheadSlot structs is used in two ways:
    // 1. It is byte-encoded to form the payload of the lookahead commitment
    // 2. The same array is hashed (using keccak256) and stored in the lookahead store
    struct LookaheadSlot {
        // The preconfer operator's committer address that is fetched from the slashing commitment.
        address committer;
        // Timestamp of the slot.
        uint256 timestamp;
        // URC registration root of the operator
        bytes32 registrationRoot;
        // Index of the Operator's registration merkle tree leaf that contains the validator for the
        // slot.
        uint256 validatorLeafIndex;
    }

    struct LookaheadHash {
        // The timestamp of the epoch.
        uint48 epochTimestamp;
        // Keccak hash of the lookahead slots for the epoch.
        bytes26 lookaheadHash;
    }

    struct LookaheadStoreConfig {
        // The size of the lookahead buffer.
        uint16 lookaheadBufferSize;
        // The minimum collateral for a registered operator to post the lookahead.
        uint80 minCollateralForPosting;
        // The minimum collateral for a registered operator to preconf.
        uint80 minCollateralForPreconfing;
    }

    struct LookaheadData {
        /// @notice Index of the slot of the proposer in the current lookahead.
        /// @dev Must be set to type(uint256).max if the proposer is from the next epoch
        uint256 slotIndex;
        /// @notice URC registration root of the lookahead poster
        bytes32 registrationRoot;
        /// @notice Current epoch lookahead slots. It is only used for validation
        /// @dev Must be provided exactly as originally posted by the previous lookahead poster
        LookaheadSlot[] currLookahead;
        /// @notice Next epoch lookahead slots. If there's no lookahead stored for next epoch, it
        /// will be updated with this value
        /// @dev IMPORTANT: Must take into account blacklist status as of one slot before the
        /// current epoch start
        /// @dev Can be empty for same-epoch proposers when next epoch lookahead already exists
        /// on-chain (gas optimization). Must be provided for cross-epoch proposers (need slot
        /// info) and fallback preconfers (responsible for posting/validation)
        LookaheadSlot[] nextLookahead;
        /// @notice Commitment signature for the lookahead poster
        /// @dev Must be set to an empty bytes if the lookahead poster is a whitelisted preconfer
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

    error CommitmentSignerMismatch();
    error CommitterMismatch();
    error InvalidLookahead();
    error InvalidLookaheadEpoch();
    error InvalidLookaheadTimestamp();
    error InvalidSlotIndex();
    error InvalidSlotTimestamp();
    error InvalidValidatorLeafIndex();
    error LookaheadNotRequired();
    error NotInbox();
    error OperatorHasBeenBlacklisted();
    error OperatorHasBeenSlashed();
    error OperatorHasInsufficientCollateral();
    error OperatorHasNotOptedIn();
    error OperatorHasNotRegistered();
    error OperatorHasUnregistered();
    error PosterHasBeenSlashed();
    error PosterHasInsufficientCollateral();
    error PosterHasNotOptedIn();
    error PosterHasUnregistered();
    error ProposerIsNotPreconfer();
    error ProposerIsNotFallbackPreconfer();
    error SlasherIsNotLookaheadSlasher();
    error SlotTimestampIsNotIncrementing();

    event LookaheadPosted(
        uint256 indexed epochTimestamp, bytes32 lookaheadHash, LookaheadSlot[] lookaheadSlots
    );

    /// @notice Calculates the lookahead hash for a given epoch and lookahead slots.
    /// @param _epochTimestamp The timestamp of the epoch.
    /// @param _lookaheadSlots The lookahead slots.
    /// @return The lookahead hash.
    function calculateLookaheadHash(
        uint256 _epochTimestamp,
        LookaheadSlot[] memory _lookaheadSlots
    )
        external
        pure
        returns (bytes26);

    /// @notice Returns the proposer context for the given lookahead input and epoch.
    /// @dev Useful for off-chain nodes to determine the next proposer/preconfer.
    /// @param _data The lookahead data for the proposer's epoch, plus the next epoch.
    /// @param _epochTimestamp The timestamp of the proposer's epoch.
    /// @return context_ The proposer context, including the proposer and submission window bounds.
    function getProposerContext(
        LookaheadData memory _data,
        uint256 _epochTimestamp
    )
        external
        view
        returns (ProposerContext memory context_);

    /// @notice Returns true if the lookahead is required for the next epoch.
    /// @return True if the lookahead is required for the next epoch, false otherwise.
    function isLookaheadRequired() external view returns (bool);

    /// @notice Returns the lookahead hash for an epoch.
    /// @param _epochTimestamp The timestamp of the epoch.
    /// @return The lookahead hash. If the epoch is not found, returns 0.
    function getLookaheadHash(uint256 _epochTimestamp) external view returns (bytes26);

    /// @notice Returns the configuration of the lookahead store.
    /// @return The configuration of the lookahead store.
    function getLookaheadStoreConfig() external pure returns (LookaheadStoreConfig memory);

    /// @notice Checks if a lookahead operator is valid for the next epoch.
    /// @dev Reverts if the operator is not valid
    /// @param _epochTimestamp The timestamp of the epoch for which the lookahead is posted.
    /// @param _registrationRoot The URC registration root of the operator.
    /// @return True if the operator is valid
    function isLookaheadOperatorValid(
        uint256 _epochTimestamp,
        bytes32 _registrationRoot
    )
        external
        view
        returns (bool);

    /// @notice Checks if a lookahead poster is valid for the next epoch.
    /// @dev Reverts if the operator is not valid
    /// @param _epochTimestamp The timestamp of the next epoch.
    /// @param _registrationRoot The URC registration root of the poster.
    /// @return True if the poster is valid
    function isLookaheadPosterValid(
        uint256 _epochTimestamp,
        bytes32 _registrationRoot
    )
        external
        view
        returns (bool);
}
