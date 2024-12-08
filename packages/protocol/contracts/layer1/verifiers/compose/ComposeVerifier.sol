// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibStrings.sol";
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

    error CV_INVALID_SUB_VERIFIER();
    error CV_INVALID_SUB_VERIFIER_ORDER();
    error CV_VERIFIERS_INSUFFICIENT();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupResolver The {IResolver} used by this rollup.
    function init(address _owner, address _rollupResolver) external initializer {
        __Essential_init(_owner, _rollupResolver);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context[] calldata _ctxs,
        bytes calldata _proof
    )
        external
        onlyFromNamed(LibStrings.B_TAIKO)
    {
        SubProof[] memory subProofs = abi.decode(_proof, (SubProof[]));
        address[] memory verifiers = new address[](subProofs.length);

        address verifier;

        for (uint256 i; i < subProofs.length; ++i) {
            require(subProofs[i].verifier != address(0), CV_INVALID_SUB_VERIFIER());
            require(subProofs[i].verifier > verifier, CV_INVALID_SUB_VERIFIER_ORDER());

            verifier = subProofs[i].verifier;
            IVerifier(verifier).verifyProof(_ctxs, subProofs[i].proof);

            verifiers[i] = verifier;
        }

        require(areVerifiersSufficient(verifiers), CV_VERIFIERS_INSUFFICIENT());
    }

    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        virtual
        returns (bool);
}
