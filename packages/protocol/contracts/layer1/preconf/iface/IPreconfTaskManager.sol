// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libs/LibEIP4788.sol";
import "../../based/ITaikoL1.sol";

/// @title IPreconfTaskManager
/// @custom:security-contact security@taiko.xyz
interface IPreconfTaskManager {
    struct LookaheadBufferEntry {
        // True when the preconfer is randomly selected
        bool isFallback;
        // Timestamp of the slot at which the provided preconfer is the L1 validator
        uint40 timestamp;
        // Timestamp of the last slot that had a valid preconfer
        uint40 prevTimestamp;
        // Address of the preconfer who is also the L1 validator
        // The preconfer will have rights to propose a block in the range (prevTimestamp, timestamp]
        address preconfer;
    }

    struct LookaheadSetParam {
        // The timestamp of the slot
        uint256 timestamp;
        // The AVS operator who is also the L1 validator for the slot and will preconf L2
        // transactions
        address preconfer;
    }

    event LookaheadUpdated(LookaheadSetParam[]);

    event ProvedIncorrectLookahead(
        address indexed poster, uint256 indexed timestamp, address indexed disputer
    );

    /// @dev The current (or provided) timestamp does not fall in the range provided by the
    /// lookahead pointer
    error InvalidLookaheadPointer();
    /// @dev The block proposer is not the assigned preconfer for the current slot/timestamp
    error SenderIsNotThePreconfer();
    /// @dev Preconfer is not present in the registry
    error PreconferNotRegistered();
    /// @dev  Epoch timestamp is incorrect
    error InvalidEpochTimestamp();
    /// @dev The timestamp in the lookahead is not of a valid future slot in the present epoch
    error InvalidSlotTimestamp();
    /// @dev The chain id on which the preconfirmation was signed is different from the current
    /// chain's id
    error PreconfirmationChainIdMismatch();
    /// @dev The dispute window for proving incorrectc lookahead or preconfirmation is over
    error MissedDisputeWindow();
    /// @dev The lookahead poster for the epoch has already been slashed or there is no lookahead
    /// for epoch
    error PosterAlreadySlashedOrLookaheadIsEmpty();
    /// @dev The lookahead preconfer matches the one the actual validator is proposing for
    error LookaheadEntryIsCorrect();
    /// @dev Cannot force push a lookahead since it is not lagging behind
    error LookaheadIsNotRequired();
    /// @dev The registry does not have a single registered preconfer
    error NoRegisteredPreconfer();

    /// @dev Accepts block proposal by an operator and forwards it to Taiko contract
    function proposeBlocksV3(
        address coinbase,
        bytes32 anchorExtraInput,
        ITaikoL1.BlockParamsV3[] calldata blockParams,
        bytes calldata txList,
        uint256 lookaheadPointer,
        LookaheadSetParam[] calldata lookaheadSetParams
    )
        external;

    /// @dev Slashes a preconfer if the validator lookahead pushed by them has an incorrect entry
    function proveIncorrectLookahead(
        uint256 lookaheadPointer,
        uint256 slotTimestamp,
        bytes calldata validatorBLSPubKey,
        LibEIP4788.InclusionProof calldata validatorInclusionProof
    )
        external;

    /// @dev Forces the lookahead to be set for the next epoch if it is lagging behind
    function forcePushLookahead(LookaheadSetParam[] calldata lookaheadSetParams) external;

    /// @dev Returns the fallback preconfer for the given epoch
    function getFallbackPreconfer(uint256 epochTimestamp) external view returns (address);

    /// @dev Returns the full 32 slot preconfer lookahead for the epoch
    function getLookaheadForEpoch(uint256 epochTimestamp)
        external
        view
        returns (address[32] memory);

    /// @dev Return the parameters required for the lookahead to be set for the given epoch
    function getLookaheadParamsForEpoch(
        uint256 epochTimestamp,
        bytes[32] calldata validatorBLSPubKeys
    )
        external
        view
        returns (LookaheadSetParam[] memory);

    /// @dev Returns true is a lookahead is not posted for an epoch
    /// @dev In the event that a lookahead was posted but later invalidated, this returns false
    function isLookaheadRequired() external view returns (bool);

    /// @dev Returns the current lookahead tail
    function getLookaheadTail() external view returns (uint256);

    /// @dev Returns the entire lookahead buffer
    function getLookaheadBuffer() external view returns (LookaheadBufferEntry[128] memory);

    /// @dev Returns the lookahead poster for an epoch
    function getLookaheadPoster(uint256 epochTimestamp) external view returns (address);

    /// @dev Returns the preconf service manager contract address
    function getPreconfServiceManager() external view returns (address);

    /// @dev Returns the preconf registry contract address
    function getPreconfRegistry() external view returns (address);

    /// @dev Returns the Taiko L1 contract address
    function getTaiko() external view returns (address);

    /// @dev Returns the beacon genesis timestamp
    function getBeaconGenesis() external view returns (uint256);

    /// @dev Returns the beacon block root contract address
    function getBeaconBlockRootContract() external view returns (address);
}
