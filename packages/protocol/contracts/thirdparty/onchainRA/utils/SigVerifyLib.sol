// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../interfaces/ISigVerifyLib.sol";
import "./RsaVerify.sol";
import "./BytesUtils.sol";

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

    function verifyAttStmtSignature(bytes memory tbs, bytes memory signature, PublicKey memory publicKey, Algorithm alg)
        public
        view
        returns (bool)
    {
        if (alg == Algorithm.RS256) {
            if (publicKey.keyType != KeyType.RSA) {
                return false;
            }
            return verifyRS256Signature(tbs, signature, publicKey.pubKey);
        } else if (alg == Algorithm.ES256) {
            if (publicKey.keyType != KeyType.ECDSA) {
                return false;
            }
            return verifyES256Signature(tbs, signature, publicKey.pubKey);
        } else if (alg == Algorithm.RS1) {
            if (publicKey.keyType != KeyType.RSA) {
                return false;
            }
            return verifyRS1Signature(tbs, signature, publicKey.pubKey);
        } else {
            revert("Unsupported algorithm");
        }
    }

    function verifyCertificateSignature(
        bytes memory tbs,
        bytes memory signature,
        PublicKey memory publicKey,
        CertSigAlgorithm alg
    ) public view returns (bool) {
        if (alg == CertSigAlgorithm.Sha256WithRSAEncryption) {
            if (publicKey.keyType != KeyType.RSA) {
                return false;
            }
            return verifyRS256Signature(tbs, signature, publicKey.pubKey);
        } else if (alg == CertSigAlgorithm.Sha1WithRSAEncryption) {
            if (publicKey.keyType != KeyType.RSA) {
                return false;
            }
            return verifyRS1Signature(tbs, signature, publicKey.pubKey);
        } else {
            revert("Unsupported algorithm");
        }
    }

    function verifyRS256Signature(bytes memory tbs, bytes memory signature, bytes memory publicKey)
        public
        view
        returns (bool sigValid)
    {
        // Parse public key
        bytes memory exponent = publicKey.substring(0, 3);
        bytes memory modulus = publicKey.substring(3, publicKey.length - 3);

        // Verify signature
        sigValid = RsaVerify.pkcs1Sha256Raw(tbs, signature, exponent, modulus);
    }

    function verifyRS1Signature(bytes memory tbs, bytes memory signature, bytes memory publicKey)
        public
        view
        returns (bool sigValid)
    {
        // Parse public key
        bytes memory exponent = publicKey.substring(0, 3);
        bytes memory modulus = publicKey.substring(3, publicKey.length - 3);

        // Verify signature
        sigValid = RsaVerify.pkcs1Sha1Raw(tbs, signature, exponent, modulus);
    }

    function verifyES256Signature(bytes memory tbs, bytes memory signature, bytes memory publicKey)
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
