// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../libs/LibBLS12381.sol";
import "../eigenlayer-mvp/iface/IAVSDirectory.sol";

interface IPreconfRegistry {
    struct Validator {
        // Preconfer that the validator proposer blocks for
        address preconfer;
        // Timestamp at which the preconfer may start proposing for the preconfer
        // 2 epochs from validator addition timestamp
        uint40 validSince;
        // Timestamp at which the preconfer must stop proposing for the preconfer
        // 2 epochs from validator removal timestamp
        uint40 validUntil;
    }

    struct ValidatorParam {
        // The public keys of the validators
        LibBLS12381.G1Point[] pubkeys;
        // The signature of the validator
        LibBLS12381.G2Point signature;
        // The timestamp at which the above signature expires
        uint256 signatureExpiry;
    }

    enum ValidatorOp {
        REMOVE,
        ADD
    }

    /// @dev Registers a preconfer by giving them a non-zero registry index
    function registerPreconfer(IAVSDirectory.SignatureWithSaltAndExpiry calldata operatorSignature)
        external;

    /// @dev Deregisters a preconfer from the registry
    function deregisterPreconfer() external;

    /// @dev Adds consensus layer validators to the system by assigning preconfers to them
    function addValidators(ValidatorParam calldata validatorsParam) external;

    /// @dev Removes active validators who are proposing for a preconfer
    function removeValidators(ValidatorParam calldata validatorParam) external;

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

    /// @dev Returns the preconfer that is proposing for a validator
    function getPreconferForValidator(
        bytes32 pubKeyHash,
        uint256 slotTimestamp
    )
        external
        view
        returns (address);
}
