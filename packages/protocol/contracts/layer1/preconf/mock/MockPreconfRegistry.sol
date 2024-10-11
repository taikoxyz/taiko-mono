// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../avs/PreconfConstants.sol";
import "../libraries/BLSSignature.sol";
import "../interfaces/IPreconfRegistry.sol";
import "../interfaces/IPreconfServiceManager.sol";
import "../interfaces/eigenlayer-mvp/IAVSDirectory.sol";

contract MockPreconfRegistry is IPreconfRegistry, Initializable {
    using BLS12381 for BLS12381.G1Point;

    IPreconfServiceManager internal immutable preconfServiceManager;

    uint256 internal nextPreconferIndex;

    // Maps the preconfer's address to an index that may change over the lifetime of a preconfer
    mapping(address preconfer => uint256 index) internal preconferToIndex;

    // Maps an index to the preconfer's address
    // We need this mapping to deregister a preconfer in O(1) time.
    // While it may also be done by just using the above map and sending a "witness" that is
    // calculated offchain,
    // we ideally do not want the node to maintain historical state.
    mapping(uint256 index => address preconfer) internal indexToPreconfer;

    // Maps a validator's BLS pub key hash to the validator's details
    mapping(bytes32 publicKeyHash => Validator validator) internal validators;

    constructor(IPreconfServiceManager _preconfServiceManager) {
        preconfServiceManager = _preconfServiceManager;
    }

    function initialize() external initializer {
        nextPreconferIndex = 1;
    }

    /**
     * @notice Registers a preconfer in the registry by giving it a non-zero index
     * @dev This function internally accesses Eigenlayer via the AVS service manager
     * @param operatorSignature The signature of the operator in the format expected by Eigenlayer
     */
    function registerPreconfer(IAVSDirectory.SignatureWithSaltAndExpiry calldata operatorSignature)
        external
    {
        // Preconfer must not have registered already
        if (preconferToIndex[msg.sender] != 0) {
            revert PreconferAlreadyRegistered();
        }

        uint256 _nextPreconferIndex = nextPreconferIndex;

        preconferToIndex[msg.sender] = _nextPreconferIndex;
        indexToPreconfer[_nextPreconferIndex] = msg.sender;

        unchecked {
            nextPreconferIndex = _nextPreconferIndex + 1;
        }

        emit PreconferRegistered(msg.sender);

        preconfServiceManager.registerOperatorToAVS(msg.sender, operatorSignature);
    }

    /**
     * @notice Deregisters a preconfer from the registry by setting its index to zero
     * @dev It assigns the index of the last preconfer to the preconfer being removed and
     * decrements the global index counter.
     */
    function deregisterPreconfer() external {
        // Preconfer must have registered already
        if (preconferToIndex[msg.sender] == 0) {
            revert PreconferNotRegistered();
        }

        unchecked {
            uint256 _nextPreconferIndex = nextPreconferIndex - 1;

            // Update to the decremented index to account for the removed preconfer
            nextPreconferIndex = _nextPreconferIndex;

            uint256 removedPreconferIndex = preconferToIndex[msg.sender];
            address lastPreconfer = indexToPreconfer[_nextPreconferIndex];

            // Remove the preconfer and exchange its index with the last preconfer
            preconferToIndex[msg.sender] = 0;
            preconferToIndex[lastPreconfer] = removedPreconferIndex;
            indexToPreconfer[removedPreconferIndex] = lastPreconfer;
        }

        emit PreconferDeregistered(msg.sender);

        preconfServiceManager.deregisterOperatorFromAVS(msg.sender);
    }

    /**
     * @notice Assigns a validator to a preconfer
     * @dev The function allows different validators to be assigned to different preconfers, but
     * generally, it will be called by a preconfer to assign validators to itself.
     * @param addValidatorParams Contains the public key, signature, expiry, and preconfer
     */
    function addValidators(AddValidatorParam[] calldata addValidatorParams) external {
        for (uint256 i; i < addValidatorParams.length; ++i) {
            // Revert if preconfer is not registered
            if (preconferToIndex[msg.sender] == 0) {
                revert PreconferNotRegistered();
            }

            // bytes memory message = _createMessage(ValidatorOp.ADD,
            // addValidatorParams[i].signatureExpiry, msg.sender);

            // Revert if any signature is invalid
            //if (!verifySignature(message, addValidatorParams[i].signature,
            // addValidatorParams[i].pubkey)) {
            //    revert InvalidValidatorSignature();
            //}

            // Revert if the signature has expired
            if (block.timestamp > addValidatorParams[i].signatureExpiry) {
                revert ValidatorSignatureExpired();
            }

            // Point compress the public key just how it is done on the consensus layer
            uint256[2] memory compressedPubKey = addValidatorParams[i].pubkey.compress();
            // Use the hash for ease of mapping
            bytes32 pubKeyHash = keccak256(abi.encodePacked(compressedPubKey));

            Validator memory validator = validators[pubKeyHash];

            // Update the validator if it has no preconfer assigned, or if it has stopped proposing
            // for the former preconfer
            if (
                validator.preconfer == address(0)
                    || (validator.stopProposingAt != 0 && block.timestamp > validator.stopProposingAt)
            ) {
                unchecked {
                    validators[pubKeyHash] = Validator({
                        preconfer: msg.sender,
                        // The delay is crucial in order to not contradict the lookahead
                        startProposingAt: uint40(block.timestamp + PreconfConstants.TWO_EPOCHS),
                        stopProposingAt: uint40(0)
                    });
                }
            } else {
                // Validator is already proposing for a preconfer
                revert ValidatorAlreadyActive();
            }

            emit ValidatorAdded(pubKeyHash, msg.sender);
        }
    }

    /**
     * @notice Unassigns a validator from a preconfer
     * @dev Instead of removing the validator immediately, we delay the removal by two epochs,
     * & set the `stopProposingAt` timestamp.
     * @param removeValidatorParams Contains the public key, signature and expiry
     */
    function removeValidators(RemoveValidatorParam[] calldata removeValidatorParams) external {
        for (uint256 i; i < removeValidatorParams.length; ++i) {
            // Point compress the public key just how it is done on the consensus layer
            uint256[2] memory compressedPubKey = removeValidatorParams[i].pubkey.compress();
            // Use the hash for ease of mapping
            bytes32 pubKeyHash = keccak256(abi.encodePacked(compressedPubKey));

            Validator memory validator = validators[pubKeyHash];

            // Revert if the validator is not active (or already removed, but waiting to stop
            // proposing)
            if (validator.preconfer == address(0) || validator.stopProposingAt != 0) {
                revert ValidatorAlreadyInactive();
            }

            bytes memory message = _createMessage(
                ValidatorOp.REMOVE, removeValidatorParams[i].signatureExpiry, validator.preconfer
            );

            // Revert if any signature is invalid
            if (
                !BLSSignature.verifySignature(
                    message, removeValidatorParams[i].signature, removeValidatorParams[i].pubkey
                )
            ) {
                revert InvalidValidatorSignature();
            }

            // Revert if the signature has expired
            if (block.timestamp > removeValidatorParams[i].signatureExpiry) {
                revert ValidatorSignatureExpired();
            }

            unchecked {
                // We also need to delay the removal by two epochs to avoid contradicting the
                // lookahead
                validators[pubKeyHash].stopProposingAt =
                    uint40(block.timestamp + PreconfConstants.TWO_EPOCHS);
            }

            emit ValidatorRemoved(pubKeyHash, validator.preconfer);
        }
    }

    //=======
    // Views
    //=======

    function getMessageToSign(
        ValidatorOp validatorOp,
        uint256 expiry,
        address preconfer
    )
        external
        view
        returns (bytes memory)
    {
        return _createMessage(validatorOp, expiry, preconfer);
    }

    function getPreconfServiceManager() external view returns (address) {
        return address(preconfServiceManager);
    }

    function getNextPreconferIndex() external view returns (uint256) {
        return nextPreconferIndex;
    }

    function getPreconferIndex(address preconfer) external view returns (uint256) {
        return preconferToIndex[preconfer];
    }

    function getPreconferAtIndex(uint256 index) external view returns (address) {
        return indexToPreconfer[index];
    }

    function getValidator(bytes32 pubKeyHash) external view returns (Validator memory) {
        return validators[pubKeyHash];
    }

    //=========
    // Helpers
    //=========

    function _createMessage(
        ValidatorOp validatorOp,
        uint256 expiry,
        address preconfer
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(block.chainid, validatorOp, expiry, preconfer);
    }
}
