// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libs/BLS12381.sol";
import "./eigenlayer-mvp/IAVSDirectory.sol";

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
        BLS12381.G1Point pubkey;
        // The signature of the validator
        BLS12381.G2Point signature;
        // The timestamp at which the above signature expires
        uint256 signatureExpiry;
    }

    struct RemoveValidatorParam {
        // The public key of the validator
        BLS12381.G1Point pubkey;
        // The signature of the validator
        BLS12381.G2Point signature;
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

    /// @dev The preconfer is already registered in the registry
    error PreconferAlreadyRegistered();
    /// @dev The preconfer is not registered in the registry
    error PreconferNotRegistered();
    /// @dev The signature is invalid
    error InvalidValidatorSignature();
    /// @dev The signature has expired
    error ValidatorSignatureExpired();
    /// @dev The validator is already proposing for a preconfer and cannot be added again without
    /// removal
    error ValidatorAlreadyActive();
    /// @dev The validator is already removed or waiting to stop proposing for a preconfer
    error ValidatorAlreadyInactive();

    /// @dev Registers a preconfer by giving them a non-zero registry index
    function registerPreconfer(IAVSDirectory.SignatureWithSaltAndExpiry calldata operatorSignature)
        external;

    /// @dev Deregisters a preconfer from the registry
    function deregisterPreconfer() external;

    /// @dev Adds consensus layer validators to the system by assigning preconfers to them
    function addValidators(AddValidatorParam[] calldata addValidatorParams) external;

    /// @dev Removes active validators who are proposing for a preconfer
    function removeValidators(RemoveValidatorParam[] calldata removeValidatorParams) external;

    /// @dev Returns the message that the validator must sign to add or remove themselves from a
    /// preconfer
    function getMessageToSign(
        ValidatorOp validatorOp,
        uint256 expiry,
        address preconfer
    )
        external
        view
        returns (bytes memory);

    /// @dev Returns the index of the next preconfer
    function getNextPreconferIndex() external view returns (uint256);

    /// @dev Returns the index of the preconfer
    function getPreconferIndex(address preconfer) external view returns (uint256);

    /// @dev Returns the preconfer at the given index
    function getPreconferAtIndex(uint256 index) external view returns (address);

    /// @dev Returns a validator who is proposing for a registered preconfer
    function getValidator(bytes32 pubKeyHash) external view returns (Validator memory);

    /// @dev Returns the address of the service manager contract
    function getPreconfServiceManager() external view returns (address);
}
