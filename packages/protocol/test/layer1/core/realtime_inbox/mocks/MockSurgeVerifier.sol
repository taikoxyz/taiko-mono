// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibProofBitmap } from "src/layer1/surge/libs/LibProofBitmap.sol";

/// @dev Mock SurgeVerifier that accepts all proofs and returns an empty bitmap.
contract MockSurgeVerifier {
    function verifyProof(
        bool,
        bytes32,
        bytes calldata
    )
        external
        pure
        returns (LibProofBitmap.ProofBitmap)
    {
        return LibProofBitmap.ProofBitmap.wrap(0);
    }
}
