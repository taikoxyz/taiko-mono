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

    address public immutable taikoInbox;
    /// The sgxGethVerifier is the core verifier required in every proof.
    /// All other proofs share its status root, despite differing public inputs.
    /// despite varying public inputs due to differing verification types.
    address public immutable sgxGethVerifier;
    address public immutable opVerifier;
    address public immutable sgxRethVerifier;
    address public immutable tdxVerifier;
    address public immutable risc0RethVerifier;
    address public immutable sp1RethVerifier;

    constructor(
        address _taikoInbox,
        address _sgxGethVerifier,
        address _opVerifier,
        address _sgxRethVerifier,
        address _tdxVerifier,
        address _risc0RethVerifier,
        address _sp1RethVerifier
    )
        EssentialContract(address(0))
    {
        taikoInbox = _taikoInbox;
        sgxGethVerifier = _sgxGethVerifier;
        opVerifier = _opVerifier;
        sgxRethVerifier = _sgxRethVerifier;
        tdxVerifier = _tdxVerifier;
        risc0RethVerifier = _risc0RethVerifier;
        sp1RethVerifier = _sp1RethVerifier;
    }

    error CV_INVALID_SUB_VERIFIER();
    error CV_INVALID_SUB_VERIFIER_ORDER();
    error CV_VERIFIERS_INSUFFICIENT();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context[] calldata _ctxs,
        bytes calldata _proof
    )
        external
        onlyFrom(taikoInbox)
    {
        SubProof[] memory subProofs = abi.decode(_proof, (SubProof[]));
        uint256 size = subProofs.length;
        address[] memory verifiers = new address[](size);

        address verifier;

        for (uint256 i; i < size; ++i) {
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
