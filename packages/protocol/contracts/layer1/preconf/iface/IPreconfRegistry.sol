// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libs/LibBLS12381.sol";

interface IPreconfRegistry {
    struct Validator {
        // Preconfer that the validator proposer blocks for
        address preconfer;
        // Timestamp at which the preconfer may start proposing for the preconfer
        // 2 epochs from validator addition timestamp
        uint40 startProposingAt;
        // Timestamp at which the preconfer must stop proposing for the preconfer
        // 2 epochs from validator removal timestamp
        uint40 stopProposingAt;
    }
    // ^ Note: 40 bits are enough for UNIX timestamp. This way we also compress the data to a single
    // slot.

    struct AddValidatorParam {
        // The public key of the validator
        LibBLS12381.G1Point pubkey;
        // The signature of the validator
        LibBLS12381.G2Point signature;
        // The timestamp at which the above signature expires
        uint256 signatureExpiry;
    }

    struct RemoveValidatorParam {
        // The public key of the validator
        LibBLS12381.G1Point pubkey;
        // The signature of the validator
        LibBLS12381.G2Point signature;
        // The timestamp at which the above signature expires
        uint256 signatureExpiry;
    }

    enum ValidatorOp {
        REMOVE,
        ADD
    }

    event PreconferRegistered(address indexed preconfer);
    event PreconferDeregistered(address indexed preconfer);
    event ValidatorAdded(bytes32 indexed pubKeyHash, address indexed preconfer);
    event ValidatorRemoved(bytes32 indexed pubKeyHash, address indexed preconfer);

    error PreconferAlreadyRegistered();
    error PreconferNotRegistered();
    error InvalidValidatorSignature();
    error ValidatorSignatureExpired();
    error ValidatorAlreadyActive();
    error ValidatorAlreadyInactive();

    /// @notice Registers a preconfer by giving them a non-zero registry index
    /// @param operatorSignature The signature of the operator
    function registerPreconfer(bytes calldata operatorSignature) external;

    /// @notice Deregisters a preconfer from the registry
    function deregisterPreconfer() external;

    /// @notice Adds consensus layer validators to the system by assigning preconfers to them
    /// @param addValidatorParams The parameters for adding validators
    function addValidators(AddValidatorParam[] calldata addValidatorParams) external;

    /// @notice Removes active validators who are proposing for a preconfer
    /// @param removeValidatorParams The parameters for removing validators
    function removeValidators(RemoveValidatorParam[] calldata removeValidatorParams) external;

    /// @notice Returns the message that the validator must sign to add or remove themselves from a
    /// preconfer
    /// @param validatorOp The operation to be performed (ADD or REMOVE)
    /// @param expiry The timestamp at which the signature expires
    /// @param preconfer The address of the preconfer
    /// @return The message to be signed by the validator
    function getMessageToSign(
        ValidatorOp validatorOp,
        uint256 expiry,
        address preconfer
    )
        external
        view
        returns (bytes memory);

    /// @notice Returns the index of the next preconfer
    /// @return The index of the next preconfer
    function getNextPreconferIndex() external view returns (uint256);

    /// @notice Returns the index of the preconfer
    /// @param preconfer The address of the preconfer
    /// @return The index of the preconfer
    function getPreconferIndex(address preconfer) external view returns (uint256);

    /// @notice Returns the preconfer at the given index
    /// @param index The index of the preconfer
    /// @return The address of the preconfer
    function getPreconferAtIndex(uint256 index) external view returns (address);

    /// @notice Returns a validator who is proposing for a registered preconfer
    /// @param pubKeyHash The hash of the public key of the validator
    /// @return The validator who is proposing for the preconfer
    function getValidator(bytes32 pubKeyHash) external view returns (Validator memory);
}
