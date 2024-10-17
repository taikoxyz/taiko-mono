// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/common/LibStrings.sol";
import "../IVerifier.sol";

/// @title ComposeVerifier
/// @notice This contract is an abstract verifier that composes multiple sub-verifiers to validate
/// proofs.
/// It ensures that a set of sub-proofs are verified by their respective verifiers before
/// considering the overall proof as valid.
/// @custom:security-contact security@taiko.xyz
abstract contract ComposeVerifier is EssentialContract, IVerifier {
    uint256[50] private __gap;

    struct SubProof {
        address verifier;
        bytes proof;
    }

    error CV_DUPLICATE_SUBPROOF();
    error CV_INVALID_CALLER();
    error CV_INVALID_SUB_VERIFIER();
    error CV_INVALID_SUBPROOF_LENGTH();
    error CV_SUB_VERIFIER_NOT_FOUND();

    modifier onlyAuthorizedCaller() {
        if (!isCallerAuthorized(msg.sender)) revert CV_INVALID_CALLER();
        _;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
        onlyAuthorizedCaller
        nonReentrant
    {
        (address[] memory verifiers, uint256 numSubProofs_) = getSubVerifiersAndThreshold();

        SubProof[] memory subProofs = abi.decode(_proof.data, (SubProof[]));
        if (subProofs.length != numSubProofs_) revert CV_INVALID_SUBPROOF_LENGTH();

        for (uint256 i; i < subProofs.length; ++i) {
            if (subProofs[i].verifier == address(0)) revert CV_INVALID_SUB_VERIFIER();

            // find the verifier
            bool verifierFound;
            for (uint256 j; j < verifiers.length; ++j) {
                if (verifiers[j] == subProofs[i].verifier) {
                    verifierFound = true;
                    verifiers[j] = address(0);
                }
            }

            if (!verifierFound) revert CV_SUB_VERIFIER_NOT_FOUND();

            IVerifier(subProofs[i].verifier).verifyProof(
                _ctx, _tran, TaikoData.TierProof(_proof.tier, subProofs[i].proof)
            );
        }
    }

    /// @inheritdoc IVerifier
    function verifyBatchProof(
        ContextV2[] calldata _ctxs,
        TaikoData.TierProof calldata _proof
    )
        external
        onlyFromNamed(LibStrings.B_TAIKO)
        nonReentrant
    {
        (address[] memory verifiers, uint256 numSubProofs_) = getSubVerifiersAndThreshold();

        SubProof[] memory subProofs = abi.decode(_proof.data, (SubProof[]));
        if (subProofs.length != numSubProofs_) revert CV_INVALID_SUBPROOF_LENGTH();

        for (uint256 i; i < subProofs.length; ++i) {
            if (subProofs[i].verifier == address(0)) revert CV_DUPLICATE_SUBPROOF();

            // find the verifier
            bool verifierFound;
            for (uint256 j; j < verifiers.length; ++j) {
                if (verifiers[j] == subProofs[i].verifier) {
                    verifierFound = true;
                    verifiers[j] = address(0);
                }
            }

            if (!verifierFound) revert CV_SUB_VERIFIER_NOT_FOUND();

            IVerifier(subProofs[i].verifier).verifyBatchProof(
                _ctxs, TaikoData.TierProof(_proof.tier, subProofs[i].proof)
            );
        }
    }

    /// @notice Returns the list of sub-verifiers and calculates the threshold.
    /// @return verifiers_ An array of addresses of sub-verifiers.
    /// @return numSubProofs_ The number of sub proofs required.
    function getSubVerifiersAndThreshold()
        public
        view
        virtual
        returns (address[] memory verifiers_, uint256 numSubProofs_);

    /// @notice Checks if the caller is authorized.
    /// @param _caller The address of the caller to be checked.
    /// @return A boolean value indicating whether the caller is authorized.
    function isCallerAuthorized(address _caller) public view virtual returns (bool) {
        return _caller == resolve(LibStrings.B_TAIKO, false);
    }
}
