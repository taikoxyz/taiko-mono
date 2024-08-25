// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";
import "../IVerifier.sol";

/// @title ComposeVerifier
/// @notice This contract is an abstract verifier that composes multiple sub-verifiers to validate
/// proofs.
/// It ensures that a set of sub-proofs are verified by their respective verifiers before
/// considering the overall proof as valid.
/// @custom:security-contact security@taiko.xyz
abstract contract ComposeVerifier is EssentialContract, IVerifier {
    struct SubProof {
        address verifier;
        bytes proof;
    }

    event InvalidSubProof(address indexed verifier, bytes returnData);

    error INVALID_VERIFIER();
    error INSUFFICIENT_PROOF();

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
    {
        (address[] memory verifiers, uint256 threshold) = getSubVerifiersAndThreshold();
        SubProof[] memory subproofs = abi.decode(_proof.data, (SubProof[]));
        uint256 numVerified;

        for (uint256 i; i < subproofs.length; ++i) {
            if (subproofs[i].verifier == address(0)) revert INVALID_VERIFIER();

            // find the verifier
            bool verifierFound;
            for (uint256 j; j < verifiers.length; ++j) {
                if (verifiers[j] == subproofs[i].verifier) {
                    verifierFound = true;
                    verifiers[j] = address(0);
                }
            }

            if (!verifierFound) revert INVALID_VERIFIER();

            (bool success, bytes memory returnData) = subproofs[i].verifier.call(
                abi.encodeCall(
                    IVerifier.verifyProof,
                    (_ctx, _tran, TaikoData.TierProof(_proof.tier, subproofs[i].proof))
                )
            );
            if (success) {
                unchecked {
                    numVerified += 1;
                }
            } else {
                emit InvalidSubProof(subproofs[i].verifier, returnData);
            }
        }

        if (numVerified < threshold) {
            revert INSUFFICIENT_PROOF();
        }
    }

    /// @inheritdoc IVerifier
    function verifyBatchProof(
        ContextV2[] calldata _ctxs,
        TaikoData.TierProof calldata _proof
    )
        external
    {
        revert("Not implemented");
    }

    /// @notice Returns the list of sub-verifiers and calculates the threshold.
    /// @return verifiers_ An array of addresses of sub-verifiers.
    /// @return threshold_ The threshold number of successful verifications required.
    function getSubVerifiersAndThreshold()
        public
        view
        virtual
        returns (address[] memory verifiers_, uint256 threshold_);
}
