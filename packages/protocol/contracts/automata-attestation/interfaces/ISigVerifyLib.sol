//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ISigVerifyLib
/// @custom:security-contact security@taiko.xyz
interface ISigVerifyLib {
    enum KeyType {
        RSA,
        ECDSA
    }

    struct PublicKey {
        KeyType keyType;
        // If RSA, pubKey = abi.encodePacked(exponent, modulus)
        // If ECDSA, pubKey = abi.encodePacked(gx, gy)
        bytes pubKey;
    }

    enum CertSigAlgorithm {
        Sha256WithRSAEncryption,
        Sha1WithRSAEncryption
    }

    struct Certificate {
        // Asn.1 DER encoding of the to-be-signed certificate
        bytes tbsCertificate;
        PublicKey publicKey;
        bytes signature;
        CertSigAlgorithm sigAlg;
    }

    enum Algorithm {
        RS256,
        ES256,
        RS1
    }

    function verifyAttStmtSignature(
        bytes memory tbs,
        bytes memory signature,
        PublicKey memory publicKey,
        Algorithm alg
    )
        external
        view
        returns (bool);

    function verifyCertificateSignature(
        bytes memory tbs,
        bytes memory signature,
        PublicKey memory publicKey,
        CertSigAlgorithm alg
    )
        external
        view
        returns (bool);

    function verifyRS256Signature(
        bytes memory tbs,
        bytes memory signature,
        bytes memory publicKey
    )
        external
        view
        returns (bool sigValid);

    function verifyRS1Signature(
        bytes memory tbs,
        bytes memory signature,
        bytes memory publicKey
    )
        external
        view
        returns (bool sigValid);

    function verifyES256Signature(
        bytes memory tbs,
        bytes memory signature,
        bytes memory publicKey
    )
        external
        view
        returns (bool sigValid);
}
