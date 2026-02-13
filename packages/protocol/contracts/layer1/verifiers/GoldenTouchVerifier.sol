// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProofVerifier } from "./IProofVerifier.sol";
import { LibPublicInput } from "./LibPublicInput.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title GoldenTouchVerifier
/// @notice Verifies proofs signed by the golden touch signer.
/// @dev This verifier is for testing or intermediate use only and must never be used in production.
/// @custom:security-contact security@taiko.xyz
contract GoldenTouchVerifier is IProofVerifier {
    /// @notice Fixed instance ID for golden touch verification.
    uint32 public constant INSTANCE_ID = 0xDEADC0DE;
    /// @notice Fixed signer address authorized for golden touch proofs.
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;

    /// @notice The Taiko chain ID for this verifier instance.
    uint64 public immutable taikoChainId;

    // Proof format: 4 bytes (instance ID) + 20 bytes (address) + 65 bytes (ECDSA signature).
    uint256 private constant EXPECTED_PROOF_LENGTH = 89;

    constructor(uint64 _taikoChainId) {
        if (_taikoChainId == 0) revert INVALID_CHAIN_ID();
        if (GOLDEN_TOUCH_ADDRESS == address(0)) revert INVALID_GOLDEN_TOUCH_ADDRESS();
        taikoChainId = _taikoChainId;
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IProofVerifier
    function verifyProof(
        uint256, /* _proposalAge */
        bytes32 _commitmentHash,
        bytes calldata _proof
    )
        external
        view
    {
        if (_proof.length != EXPECTED_PROOF_LENGTH) revert GOLDEN_TOUCH_INVALID_PROOF();

        uint32 id = uint32(bytes4(_proof[:4]));
        if (id != INSTANCE_ID) revert GOLDEN_TOUCH_INVALID_INSTANCE_ID();

        address instance = address(bytes20(_proof[4:24]));
        if (instance != GOLDEN_TOUCH_ADDRESS) revert GOLDEN_TOUCH_INVALID_INSTANCE_ADDRESS();

        bytes32 signatureHash =
            LibPublicInput.hashPublicInputs(_commitmentHash, address(this), instance, taikoChainId);

        bytes memory signature = _proof[24:];
        (address recovered, ECDSA.RecoverError err) = ECDSA.tryRecover(signatureHash, signature);
        if (err != ECDSA.RecoverError.NoError || recovered != GOLDEN_TOUCH_ADDRESS) {
            revert GOLDEN_TOUCH_INVALID_PROOF();
        }
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    /// @notice Thrown when the chain ID is zero during construction.
    error INVALID_CHAIN_ID();
    /// @notice Thrown when the golden touch address is zero.
    error INVALID_GOLDEN_TOUCH_ADDRESS();
    /// @notice Thrown when the proof format or signature is invalid.
    error GOLDEN_TOUCH_INVALID_PROOF();
    /// @notice Thrown when the proof instance ID is invalid.
    error GOLDEN_TOUCH_INVALID_INSTANCE_ID();
    /// @notice Thrown when the proof instance address is invalid.
    error GOLDEN_TOUCH_INVALID_INSTANCE_ADDRESS();
}
