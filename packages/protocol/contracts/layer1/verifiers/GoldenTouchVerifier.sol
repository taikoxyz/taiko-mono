// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProofVerifier } from "./IProofVerifier.sol";
import { LibPublicInput } from "./LibPublicInput.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title GoldenTouchVerifier
/// @notice Verifies proofs signed by the golden touch signer.
/// @custom:security-contact security@taiko.xyz
contract GoldenTouchVerifier is IProofVerifier {
    uint32 public constant INSTANCE_ID = 0xDEADC0DE;
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;

    uint64 public immutable taikoChainId;

    constructor(uint64 _taikoChainId) {
        if (_taikoChainId == 0) revert INVALID_CHAIN_ID();
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
        if (_proof.length != 89) revert GOLDEN_TOUCH_INVALID_PROOF();

        uint32 id = uint32(bytes4(_proof[:4]));
        if (id != INSTANCE_ID) revert GOLDEN_TOUCH_INVALID_INSTANCE();

        address instance = address(bytes20(_proof[4:24]));
        if (instance != GOLDEN_TOUCH_ADDRESS) revert GOLDEN_TOUCH_INVALID_INSTANCE();

        bytes32 signatureHash =
            LibPublicInput.hashPublicInputs(_commitmentHash, address(this), instance, taikoChainId);

        bytes memory signature = _proof[24:];
        if (GOLDEN_TOUCH_ADDRESS != ECDSA.recover(signatureHash, signature)) {
            revert GOLDEN_TOUCH_INVALID_PROOF();
        }
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error INVALID_CHAIN_ID();
    error GOLDEN_TOUCH_INVALID_PROOF();
    error GOLDEN_TOUCH_INVALID_INSTANCE();
}
