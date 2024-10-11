// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "src/layer1/avs-mvp/iface/IAVSDirectory.sol";
import "../iface/IPreconfRegistry.sol";
import "../iface/IPreconfServiceManager.sol";
import "../libs/BLSSignature.sol";
import "./PreconfConstants.sol";

contract PreconfRegistry is IPreconfRegistry, Initializable {
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

    uint256[46] private __gap; // = 50 - 4

    constructor(IPreconfServiceManager _preconfServiceManager) {
        preconfServiceManager = _preconfServiceManager;
    }

    function initialize() external initializer {
        nextPreconferIndex = 1;
    }

    /**
     * @notice Registers a preconfer in the registry by giving it a non-zero index
     * @dev This function internally accesses the restaking platform via the AVS service manager
     * @param operatorSignature The signature of the operator in the format expected by the
     * restaking platform
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
        uint256 removedPreconferIndex = preconferToIndex[msg.sender];
        if (removedPreconferIndex == 0) {
            revert PreconferNotRegistered();
        }

        // Remove the preconfer and exchange its index with the last preconfer
        preconferToIndex[msg.sender] = 0;

        unchecked {
            // Update to the decremented index to account for the removed preconfer
            uint256 lastPreconferIndex = nextPreconferIndex - 1;
            nextPreconferIndex = lastPreconferIndex;

            if (removedPreconferIndex == lastPreconferIndex) {
                indexToPreconfer[removedPreconferIndex] = address(0);
            } else {
                address lastPreconfer = indexToPreconfer[lastPreconferIndex];
                preconferToIndex[lastPreconfer] = removedPreconferIndex;
                indexToPreconfer[removedPreconferIndex] = lastPreconfer;
            }
        }

        emit PreconferDeregistered(msg.sender);

        preconfServiceManager.deregisterOperatorFromAVS(msg.sender);
    }

    /**
     * @notice Assigns a validator to a preconfer
     * @dev This function verifies BLS signatures which is a very expensive operation costing about
     * ~350K units of gas per signature.
     * @param addValidatorParams Contains the public key, signature, expiry, and preconfer
     */
    function addValidators(AddValidatorParam[] calldata addValidatorParams) external {
        for (uint256 i; i < addValidatorParams.length; ++i) {
            // Revert if preconfer is not registered
            if (preconferToIndex[msg.sender] == 0) {
                revert PreconferNotRegistered();
            }

            // Note: BLS signature checks are commented out for the POC

            // bytes memory message = _createMessage(ValidatorOp.ADD,
            // addValidatorParams[i].signatureExpiry, msg.sender);

            // Revert if any signature is invalid
            // if (!verifySignature(message, addValidatorParams[i].signature,
            // addValidatorParams[i].pubkey)) {
            //     revert InvalidValidatorSignature();
            // }

            // Revert if the signature has expired
            // if (block.timestamp > addValidatorParams[i].signatureExpiry) {
            //     revert ValidatorSignatureExpired();
            // }

            bytes32 pubKeyHash = _hashBLSPubKey(addValidatorParams[i].pubkey);
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
            bytes32 pubKeyHash = _hashBLSPubKey(removeValidatorParams[i].pubkey);
            Validator memory validator = validators[pubKeyHash];

            // Revert if the validator is not active (or already removed, but waiting to stop
            // proposing)
            if (validator.preconfer == address(0) || validator.stopProposingAt != 0) {
                revert ValidatorAlreadyInactive();
            }

            // Note: BLS signature checks have been commented out
            // Todo: It would be reasonable to remove BLS checks altogether for validator removals.

            // bytes memory message =
            //     _createMessage(ValidatorOp.REMOVE, removeValidatorParams[i].signatureExpiry,
            // validator.preconfer);

            // // Revert if any signature is invalid
            // if (!verifySignature(message, removeValidatorParams[i].signature,
            // removeValidatorParams[i].pubkey)) {
            //     revert InvalidValidatorSignature();
            // }

            // // Revert if the signature has expired
            // if (block.timestamp > removeValidatorParams[i].signatureExpiry) {
            //     revert ValidatorSignatureExpired();
            // }

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

    function _hashBLSPubKey(BLS12381.G1Point calldata pubkey) internal pure returns (bytes32) {
        uint256[2] memory compressedPubKey = pubkey.compress();
        return keccak256(abi.encodePacked(compressedPubKey));
    }
}
