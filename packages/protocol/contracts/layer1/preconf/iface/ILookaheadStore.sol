// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@eth-fabric/urc/ISlasher.sol";

/// @title ILookaheadStore
/// @custom:security-contact security@taiko.xyz
interface ILookaheadStore {
    // An array of `LookaheadPayload` will be byte-encoded to be the payload of the
    // lookahead commitment.
    struct LookaheadPayload {
        // Timestamp of the L1 slot
        uint48 slotTimestamp;
        // Registration root of the operator in the URC
        bytes32 registrationRoot;
        // Index of the Operator's registration merkle tree leaf that contains the validator
        // for the slot
        uint256 validatorLeafIndex;
    }

    struct LookaheadSlot {
        // The preconfer operator's committer address that is fetched from the slashing commitment.
        address committer;
        // Timestamp of the slot.
        uint256 slotTimestamp;
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

    struct Config {
        // The size of the lookahead buffer.
        uint16 lookaheadBufferSize;
        // The minimum collateral for a registered operator to post the lookahead.
        uint80 minCollateralForPosting;
        // The minimum collateral for a registered operator to preconf.
        uint80 minCollateralForPreconfing;
    }

    error CommitmentSignerMismatch();
    error InvalidLookaheadEpoch();
    error InvalidSlotTimestamp();
    error InvalidValidatorLeafIndex();
    error LookaheadNotRequired();
    error OperatorHasBeenSlashed();
    error OperatorHasInsufficientCollateral();
    error OperatorHasNotOptedIn();
    error OperatorHasNotRegistered();
    error OperatorHasUnregistered();
    error PosterHasBeenSlashed();
    error PosterHasInsufficientCollateral();
    error PosterHasNotOptedIn();
    error PosterHasUnregistered();
    error SlasherIsNotProtector();
    error SlotTimestampIsNotIncrementing();

    event LookaheadPosted(
        bool indexed isPostedByProtector,
        uint256 indexed epochTimestamp,
        bytes32 lookaheadHash,
        LookaheadSlot[] lookaheadSlot
    );

    /// @notice Allows a registered operator to post the lookahead for the next epoch.
    /// @param _registrationRoot The registration root of the posting-operator in the URC.
    /// @param _data The signed commitment containing the lookahead data, or the lookahead data if
    /// posted by the protector.
    function updateLookahead(bytes32 _registrationRoot, bytes calldata _data) external;

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

    /// @notice Returns true if the lookahead is required for the next epoch.
    /// @return True if the lookahead is required for the next epoch, false otherwise.
    function isLookaheadRequired() external view returns (bool);

    /// @notice Returns the lookahead hash for an epoch.
    /// @param _epochTimestamp The timestamp of the epoch.
    /// @return The lookahead hash. If the epoch is not found, returns 0.
    function getLookaheadHash(uint256 _epochTimestamp) external view returns (bytes26);

    /// @notice Returns the configuration of the lookahead store.
    /// @return The configuration of the lookahead store.
    function getConfig() external pure returns (Config memory);
}
