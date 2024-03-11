// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import "../interfaces/ISigVerifyLib.sol";
import "./RsaVerify.sol";
import "./BytesUtils.sol";

/// @title SigVerifyLib
/// @custom:security-contact security@taiko.xyz
// Library for verifying signatures
// Supports verifying signatures with the following algorithms:
// - RS256
// - ES256
// - RS1
contract SigVerifyLib is ISigVerifyLib {
    using BytesUtils for bytes;

    address private ES256VERIFIER;

    constructor(address es256Verifier) {
        ES256VERIFIER = es256Verifier;
    }

    function verifyES256Signature(
        bytes memory tbs,
        bytes memory signature,
        bytes memory publicKey
    )
        public
        view
        returns (bool sigValid)
    {
        // Parse signature
        if (signature.length != 64) {
            return false;
        }
        uint256 r = uint256(bytes32(signature.substring(0, 32)));
        uint256 s = uint256(bytes32(signature.substring(32, 32)));
        // Parse public key
        if (publicKey.length != 64) {
            return false;
        }
        uint256 gx = uint256(bytes32(publicKey.substring(0, 32)));
        uint256 gy = uint256(bytes32(publicKey.substring(32, 32)));

        // Verify signature
        bytes memory args = abi.encode(sha256(tbs), r, s, gx, gy);
        (bool success, bytes memory ret) = ES256VERIFIER.staticcall(args);
        assert(success); // never reverts, always returns 0 or 1

        return abi.decode(ret, (uint256)) == 1;
    }
}
