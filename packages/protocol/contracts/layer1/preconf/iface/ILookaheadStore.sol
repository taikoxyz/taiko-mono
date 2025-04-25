// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@eth-fabric/urc/ISlasher.sol";

interface ILookaheadStore {
    // An array of `LookaheadPayloadEntry` will be byte-encoded to be the payload of the
    // lookahead commitment.
    struct LookaheadPayloadEntry {
        // Timestamp of the L1 slot
        uint256 slotTimestamp;
        // Registration root of the operator in the URC
        bytes32 registrationRoot;
        // Index of the Operator's registration merkle tree leaf that contains the validator
        // for the slot
        uint256 leafIndex;
    }

    struct LookaheadBufferEntry {
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

    struct Config {
        // The size of the lookahead buffer.
        uint16 lookaheadBufferSize;
        // The minimum collateral for a registered operator to post the lookahead.
        uint80 minCollateralForPosting;
        // The minimum collateral for a registered operator to preconf.
        uint80 minCollateralForPreconfing;
    }

    error LookaheadNotRequired();
    error PosterHasUnregistered();
    error PosterHasBeenSlashed();
    error PosterHasInsufficientCollateral();
    error PosterHasNotOptedIn();
    error CommittmentSignerMismatch();
    error SlasherIsNotGuardian();
    error InvalidLookaheadEpoch();
    error SlotTimestampIsNotIncrementing();
    error InvalidSlotTimestamp();
    error OperatorHasUnregistered();
    error OperatorHasBeenSlashed();
    error OperatorHasInsufficientCollateral();
    error InvalidValidatorLeafIndex();
    error OperatorHasNotOptedIntoPreconfSlasher();

    event LookaheadRootUpdated(uint256 epochTimestamp, bytes32 lookaheadRoot);
    event LookaheadEntryPosted(
        uint256 indexed timestamp,
        uint256 prevTimestamp,
        address committer,
        uint256 validatorLeafIndex
    );

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
     * @notice Returns true if the lookahead is required for the next epoch.
     * @return True if the lookahead is required for the next epoch, false otherwise.
     */
    function isLookaheadRequired() external view returns (bool);

    /**
     * @notice Returns the configuration of the lookahead store.
     * @return The configuration of the lookahead store.
     */
    function lookaheadStoreConfig() external pure returns (Config memory);
}
