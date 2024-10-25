// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libs/LibEIP4788.sol";

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
    /// @dev Epoch timestamp is incorrect
    error InvalidEpochTimestamp();
    /// @dev The timestamp in the lookahead is not of a valid future slot in the present epoch
    error InvalidSlotTimestamp();
    /// @dev The chain id on which the preconfirmation was signed is different from the current
    /// chain's id
    error PreconfirmationChainIdMismatch();
    /// @dev The dispute window for proving incorrect lookahead or preconfirmation is over
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

    /// @notice Accepts block proposal by an operator and forwards it to TaikoL1 contract
    /// @param blockParamsArr Array of block parameters
    /// @param txListArr Array of transaction lists
    /// @param lookaheadPointer Pointer to the lookahead
    /// @param lookaheadSetParams Array of lookahead set parameters
    function newBlockProposals(
        bytes[] calldata blockParamsArr,
        bytes[] calldata txListArr,
        uint256 lookaheadPointer,
        LookaheadSetParam[] calldata lookaheadSetParams
    )
        external;

    /// @notice Slashes a preconfer if the validator lookahead pushed by them has an incorrect entry
    /// @param lookaheadPointer Pointer to the lookahead
    /// @param slotTimestamp Timestamp of the slot
    /// @param validatorBLSPubKey BLS public key of the validator
    /// @param validatorInclusionProof Inclusion proof of the validator
    function proveIncorrectLookahead(
        uint256 lookaheadPointer,
        uint256 slotTimestamp,
        bytes calldata validatorBLSPubKey,
        LibEIP4788.InclusionProof calldata validatorInclusionProof
    )
        external;

    /// @notice Forces the lookahead to be set for the next epoch if it is lagging behind
    /// @param lookaheadSetParams Array of lookahead set parameters
    function forcePushLookahead(LookaheadSetParam[] calldata lookaheadSetParams) external;

    /// @notice Returns the fallback preconfer for the given epoch
    /// @param epochTimestamp Timestamp of the epoch
    /// @return address of the fallback preconfer
    function getFallbackPreconfer(uint256 epochTimestamp) external view returns (address);

    /// @notice Returns the full 32 slot preconfer lookahead for the epoch
    /// @param epochTimestamp Timestamp of the epoch
    /// @return address[32] memory Array of preconfer addresses
    function getLookaheadForEpoch(uint256 epochTimestamp)
        external
        view
        returns (address[32] memory);

    /// @notice Return the parameters required for the lookahead to be set for the given epoch
    /// @param epochTimestamp Timestamp of the epoch
    /// @param validatorBLSPubKeys Array of BLS public keys of the validators
    /// @return LookaheadSetParam[] memory Array of lookahead set parameters
    function getLookaheadParamsForEpoch(
        uint256 epochTimestamp,
        bytes[32] calldata validatorBLSPubKeys
    )
        external
        view
        returns (LookaheadSetParam[] memory);

    /// @notice Returns true if a lookahead is not posted for an epoch
    /// @dev In the event that a lookahead was posted but later invalidated, this returns false
    /// @return bool True if lookahead is required, false otherwise
    function isLookaheadRequired() external view returns (bool);

    /// @notice Returns the current lookahead tail
    /// @return uint256 Current lookahead tail
    function getLookaheadTail() external view returns (uint256);

    /// @notice Returns the entire lookahead buffer
    /// @return LookaheadBufferEntry[128] memory Array of lookahead buffer entries
    function getLookaheadBuffer() external view returns (LookaheadBufferEntry[128] memory);

    /// @notice Returns the lookahead poster for an epoch
    /// @param epochTimestamp Timestamp of the epoch
    /// @return address of the lookahead poster
    function getLookaheadPoster(uint256 epochTimestamp) external view returns (address);

    /// @notice Returns the preconf service manager contract address
    /// @return address of the preconf service manager contract
    function getPreconfServiceManager() external view returns (address);

    /// @notice Returns the preconf registry contract address
    /// @return address of the preconf registry contract
    function getPreconfRegistry() external view returns (address);

    /// @notice Returns the Taiko L1 contract address
    /// @return address of the Taiko L1 contract
    function getTaikoL1() external view returns (address);

    /// @notice Returns the beacon genesis timestamp
    /// @return uint256 Beacon genesis timestamp
    function getBeaconGenesis() external view returns (uint256);

    /// @notice Returns the beacon block root contract address
    /// @return address of the beacon block root contract
    function getBeaconBlockRootContract() external view returns (address);
}
