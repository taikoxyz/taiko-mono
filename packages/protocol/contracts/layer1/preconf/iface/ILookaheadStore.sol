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
        uint256 slotTimestamp;
        // Registration root of the operator in the URC
        bytes32 registrationRoot;
        // Index of the Operator's registration merkle tree leaf that contains the validator
        // for the slot
        uint256 validatorLeafIndex;
    }

    struct LookaheadLeaf {
        // Index of the lookahead leaf.
        uint256 index;
        // Timestamp of the slot.
        uint256 timestamp;
        // Pointer to the last entry's timestamp.
        // For the first lookahead entry in the epoch, this points to the global
        // `lastRecordedSlotTimestamp`
        uint256 prevTimestamp;
        // The preconfer operator's committer address that is fetched from the slashing commitment.
        address committer;
        // URC registration root of the operator
        bytes32 operatorRegistrationRoot;
        // Index of the Operator's registration merkle tree leaf that contains the validator for the
        // slot.
        uint256 validatorLeafIndex;
    }

    struct LookaheadRoot {
        // The timestamp of the epoch.
        uint256 epochTimestamp;
        // The lookahead root.
        bytes32 root;
    }

    struct Config {
        // The size of the lookahead buffer.
        uint16 lookaheadBufferSize;
        // The minimum collateral for a registered operator to post the lookahead.
        uint80 minCollateralForPosting;
        // The minimum collateral for a registered operator to preconf.
        uint80 minCollateralForPreconfing;
    }

    error CommittmentSignerMismatch();
    error InvalidLookaheadEpoch();
    error InvalidSlotTimestamp();
    error InvalidValidatorLeafIndex();
    error LookaheadNotRequired();
    error LookaheadRootNotFound();
    error OperatorHasBeenSlashed();
    error OperatorHasInsufficientCollateral();
    error OperatorHasNotOptedIntoPreconfSlasher();
    error OperatorHasUnregistered();
    error PosterHasBeenSlashed();
    error PosterHasInsufficientCollateral();
    error PosterHasNotOptedIn();
    error PosterHasUnregistered();
    error SlasherIsNotGuardian();
    error SlotTimestampIsNotIncrementing();

    event LookaheadRootUpdated(uint256 epochTimestamp, bytes32 lookaheadRoot);
    event LookaheadLeafPosted(uint256 indexed timestamp, LookaheadLeaf lookaheadLeaf);

    /**
     * @notice Allows a registered operator to post the lookahead for the next epoch.
     * @param registrationRoot The registration root of the posting-operator in the URC.
     * @param signedCommitment The signed commitment containing the lookahead data.
     */
    function updateLookahead(
        bytes32 registrationRoot,
        ISlasher.SignedCommitment memory signedCommitment
    )
        external;

    /**
     * @notice Called by the guardian to overwrite the lookahead root for an epoch.
     * @param epochTimestamp The timestamp of the epoch.
     * @param lookaheadRoot The lookahead root.
     */
    function overwriteLookahead(uint256 epochTimestamp, bytes32 lookaheadRoot) external;

    /**
     * @notice Returns true if the lookahead is required for the next epoch.
     * @return True if the lookahead is required for the next epoch, false otherwise.
     */
    function isLookaheadRequired() external view returns (bool);

    /**
     * @notice Returns the lookahead root for an epoch.
     * @param epochTimestamp The timestamp of the epoch.
     * @return The lookahead root.
     */
    function getLookaheadRoot(uint256 epochTimestamp) external view returns (bytes32);

    /**
     * @notice Returns the configuration of the lookahead store.
     * @return The configuration of the lookahead store.
     */
    function getConfig() external pure returns (Config memory);
}
