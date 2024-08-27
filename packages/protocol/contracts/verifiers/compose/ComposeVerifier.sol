// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";
import "../../common/LibStrings.sol";
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

    error DUPLICATE_SUBPROOF();
    error INVALID_CALLER();
    error INVALID_SUBPROOF_LENGTH();
    error SUB_VERIFIER_NOT_FOUND();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @notice Verifies one or more sub-proofs.
    /// @param _ctx The context of the proof verification.
    /// @param _tran The transition to verify.
    /// @param _proof The proof to verify.
    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
        onlyFromNamed(LibStrings.B_TAIKO)
    {
        (address[] memory verifiers, uint256 numSubProofs_) = getSubVerifiersAndThreshold();

        SubProof[] memory subProofs = abi.decode(_proof.data, (SubProof[]));
        if (subProofs.length != numSubProofs_) revert INVALID_SUBPROOF_LENGTH();

        for (uint256 i; i < subProofs.length; ++i) {
            if (subProofs[i].verifier == address(0)) revert DUPLICATE_SUBPROOF();

            // find the verifier
            bool verifierFound;
            for (uint256 j; j < verifiers.length; ++j) {
                if (verifiers[j] == subProofs[i].verifier) {
                    verifierFound = true;
                    verifiers[j] = address(0);
                }
            }

            if (!verifierFound) revert SUB_VERIFIER_NOT_FOUND();

            IVerifier(subProofs[i].verifier).verifyProof(
                _ctx, _tran, TaikoData.TierProof(_proof.tier, subProofs[i].proof)
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
}
