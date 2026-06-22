// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Asn1Decode, NodePtr} from "../utils/Asn1Decode.sol";
import {BytesUtils} from "../utils/BytesUtils.sol";
import {DateTimeUtils} from "../utils/DateTimeUtils.sol";

/**
 * @title Solidity Structure representing X509 Certificates
 * @notice This is a simplified structure of a DER-decoded X509 Certificate
 */
struct X509CertObj {
    uint256 serialNumber;
    string issuerCommonName;
    uint256 validityNotBefore;
    uint256 validityNotAfter;
    string subjectCommonName;
    bytes subjectPublicKey;
    // the extension needs to be parsed further for PCK Certificates
    uint256 extensionPtr;
    bytes authorityKeyIdentifier;
    bytes subjectKeyIdentifier;
    // for signature verification in the cert chain
    bytes signature;
    bytes tbs;
}

// 2.5.4.3
bytes constant COMMON_NAME_OID = hex"550403";
// 2.5.29.35
bytes constant AUTHORITY_KEY_IDENTIFIER_OID = hex"551D23";
// 2.5.29.14
bytes constant SUBJECT_KEY_IDENTIFIER_OID = hex"551D0E";

/**
 * @title X509 Certificates Helper Contract
 * @notice This is a standalone contract that can be used by off-chain applications and smart contracts
 * to parse DER-encoded X509 certificates.
 * @dev This parser is only valid for ECDSA signature algorithm and p256 key algorithm.
 */
contract X509Helper {
    using Asn1Decode for bytes;
    using NodePtr for uint256;
    using BytesUtils for bytes;

    /// =================================================================================
    /// USE THE GETTERS BELOW IF YOU DON'T WANT TO PARSE THE ENTIRE X509 CERTIFICATE
    /// =================================================================================

    function getTbsAndSig(bytes calldata der) external pure returns (bytes memory tbs, bytes memory sig) {
        uint256 root = der.root();
        uint256 tbsParentPtr = der.firstChildOf(root);
        uint256 sigPtr = der.nextSiblingOf(tbsParentPtr);
        sigPtr = der.nextSiblingOf(sigPtr);

        tbs = der.allBytesAt(tbsParentPtr);
        sig = _getSignature(der, sigPtr);
    }

    function getSerialNumber(bytes calldata der) external pure returns (uint256 serialNum) {
        uint256 root = der.root();
        uint256 tbsParentPtr = der.firstChildOf(root);
        uint256 tbsPtr = der.firstChildOf(tbsParentPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        serialNum = _parseSerialNumber(der, tbsPtr);
    }

    function getIssuerCommonName(bytes calldata der) external pure returns (string memory issuerCommonName) {
        uint256 root = der.root();
        uint256 tbsParentPtr = der.firstChildOf(root);
        uint256 tbsPtr = der.firstChildOf(tbsParentPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        issuerCommonName = _getCommonName(der, tbsPtr);
    }

    function getCertValidity(bytes calldata der)
        external
        pure
        returns (uint256 validityNotBefore, uint256 validityNotAfter)
    {
        uint256 root = der.root();
        uint256 tbsParentPtr = der.firstChildOf(root);
        uint256 tbsPtr = der.firstChildOf(tbsParentPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        (validityNotBefore, validityNotAfter) = _getValidity(der, tbsPtr);
    }

    function getSubjectCommonName(bytes calldata der) external pure returns (string memory subjectCommonName) {
        uint256 root = der.root();
        uint256 tbsParentPtr = der.firstChildOf(root);
        uint256 tbsPtr = der.firstChildOf(tbsParentPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        subjectCommonName = _getCommonName(der, tbsPtr);
    }

    function getSubjectPublicKey(bytes calldata der) external pure returns (bytes memory pubKey) {
        uint256 root = der.root();
        uint256 tbsParentPtr = der.firstChildOf(root);
        uint256 tbsPtr = der.firstChildOf(tbsParentPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        pubKey = _getSubjectPublicKey(der, der.firstChildOf(tbsPtr));
    }

    function getExtensionPtr(bytes calldata der) external pure returns (uint256 extensionPtr) {
        extensionPtr = _getExtensionPtr(der);
    }

    /// @dev according to RFC 5280, the Authority Key Identifier is mandatory for CA certificates
    /// @dev if not present, this method returns 0x00
    function getAuthorityKeyIdentifier(bytes calldata der) external pure returns (bytes memory akid) {
        uint256 extensionPtr = _getExtensionPtr(der);
        uint256 extnValuePtr = _findExtensionValuePtr(der, extensionPtr, AUTHORITY_KEY_IDENTIFIER_OID);
        if (extnValuePtr != 0) {
            akid = _getAuthorityKeyIdentifier(der, extnValuePtr);
        }
    }

    /// @dev according to RFC 5280, the Subject Key Identifier is RECOMMENDED for CA certificates
    /// @dev Intel DCAP attestation certificates contain this extension
    /// @dev this value can be useful for checking CRLs without performing signature verification, which can be costly in terms of gas
    /// @dev we can simply use this value to check against the CRL's authority key identifier
    /// @dev if not present, this method returns 0x00
    function getSubjectKeyIdentifier(bytes calldata der) external pure returns (bytes memory skid) {
        uint256 extensionPtr = _getExtensionPtr(der);
        uint256 extValuePtr = _findExtensionValuePtr(der, extensionPtr, SUBJECT_KEY_IDENTIFIER_OID);

        if (extValuePtr != 0) {
            skid = _getSubjectKeyIdentifier(der, extValuePtr);
        }
    }

    /// x509 Certificates generally contain a sequence of elements in the following order:
    /// 1. tbs
    /// - 1a. version
    /// - 1b. serial number
    /// - 1c. signature algorithm
    /// - 1d. issuer
    /// - - 1d(a). common name
    /// - - 1d(b). organization name
    /// - - 1d(c). locality name
    /// - - 1d(d). state or province name
    /// - - 1d(e). country name
    /// - 1e. validity
    /// - - 1e(a) notBefore
    /// - - 1e(b) notAfter
    /// - 1f. subject
    /// - - contains the same set of elements as 1d
    /// - 1g. subject public key info
    /// - - 1g(a). algorithm
    /// - - 1g(b). subject public key
    /// - 1h. Extensions
    /// 2. Signature Algorithm
    /// 3. Signature
    function parseX509DER(bytes calldata der) external pure returns (X509CertObj memory cert) {
        uint256 root = der.root();

        uint256 tbsParentPtr = der.firstChildOf(root);
        cert.tbs = der.allBytesAt(tbsParentPtr);

        uint256 tbsPtr = der.firstChildOf(tbsParentPtr);

        tbsPtr = der.nextSiblingOf(tbsPtr);

        cert.serialNumber = _parseSerialNumber(der, tbsPtr);

        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);

        cert.issuerCommonName = _getCommonName(der, tbsPtr);

        tbsPtr = der.nextSiblingOf(tbsPtr);
        (cert.validityNotBefore, cert.validityNotAfter) = _getValidity(der, tbsPtr);

        tbsPtr = der.nextSiblingOf(tbsPtr);

        cert.subjectCommonName = _getCommonName(der, tbsPtr);

        tbsPtr = der.nextSiblingOf(tbsPtr);
        cert.subjectPublicKey = _getSubjectPublicKey(der, der.firstChildOf(tbsPtr));

        uint256 extensionPtr = der.nextSiblingOf(tbsPtr);
        if (bytes1(der[extensionPtr.ixs()]) == 0xA3) {
            cert.extensionPtr = extensionPtr;
            uint256 authorityKeyIdentifierPtr = _findExtensionValuePtr(der, extensionPtr, AUTHORITY_KEY_IDENTIFIER_OID);
            if (authorityKeyIdentifierPtr != 0) {
                cert.authorityKeyIdentifier = _getAuthorityKeyIdentifier(der, authorityKeyIdentifierPtr);
            }
            uint256 subjectKeyIdentifierPtr = _findExtensionValuePtr(der, extensionPtr, SUBJECT_KEY_IDENTIFIER_OID);
            if (subjectKeyIdentifierPtr != 0) {
                cert.subjectKeyIdentifier = _getSubjectKeyIdentifier(der, subjectKeyIdentifierPtr);
            }
        } else {
            revert("Extension is missing");
        }

        // tbs iteration completed
        // now we just need to look for the signature

        uint256 sigPtr = der.nextSiblingOf(tbsParentPtr);
        sigPtr = der.nextSiblingOf(sigPtr);
        cert.signature = _getSignature(der, sigPtr);
    }

    function _parseSerialNumber(bytes calldata der, uint256 serialNumberPtr) private pure returns (uint256 serial) {
        require(bytes1(der[serialNumberPtr.ixs()]) == 0x02, "not an integer");
        bytes memory serialBytes = der.bytesAt(serialNumberPtr);
        uint256 shift = 8 * (32 - serialBytes.length);
        serial = uint256(bytes32(serialBytes) >> shift);
    }

    function _getCommonName(bytes calldata der, uint256 rdnParentPtr) private pure returns (string memory) {
        // All we are doing here is iterating through a sequence of
        // one or many RelativeDistinguishedName (RDN) sets
        // which consists of one or many AttributeTypeAndValue sequences
        // we are only interested in the sequence with the CommonName type

        uint256 rdnPtr = der.firstChildOf(rdnParentPtr);
        bool commonNameFound = false;
        while (rdnPtr != 0) {
            uint256 sequencePtr = der.firstChildOf(rdnPtr);
            while (sequencePtr.ixl() <= rdnPtr.ixl()) {
                uint256 oidPtr = der.firstChildOf(sequencePtr);
                if (BytesUtils.compareBytes(der.bytesAt(oidPtr), COMMON_NAME_OID)) {
                    commonNameFound = true;
                    return string(der.bytesAt(der.nextSiblingOf(oidPtr)));
                } else if (sequencePtr.ixl() == rdnPtr.ixl()) {
                    break;
                } else {
                    sequencePtr = der.nextSiblingOf(sequencePtr);
                }
            }
            if (rdnPtr.ixl() < rdnParentPtr.ixl()) {
                rdnPtr = der.nextSiblingOf(rdnPtr);
            } else {
                rdnPtr = 0;
            }
        }

        if (!commonNameFound) {
            revert("Missing common name");
        }
    }

    function _getValidity(bytes calldata der, uint256 validityPtr)
        private
        pure
        returns (uint256 notBefore, uint256 notAfter)
    {
        uint256 notBeforePtr = der.firstChildOf(validityPtr);
        uint256 notAfterPtr = der.nextSiblingOf(notBeforePtr);
        notBefore = DateTimeUtils.fromDERToTimestamp(der.bytesAt(notBeforePtr));
        notAfter = DateTimeUtils.fromDERToTimestamp(der.bytesAt(notAfterPtr));
    }

    function _getSubjectPublicKey(bytes calldata der, uint256 subjectPublicKeyInfoPtr)
        private
        pure
        returns (bytes memory pubKey)
    {
        subjectPublicKeyInfoPtr = der.nextSiblingOf(subjectPublicKeyInfoPtr);
        pubKey = der.bitstringAt(subjectPublicKeyInfoPtr);
        if (pubKey.length != 65) {
            // TODO: we need to figure out how to handle key with prefix byte 0x02 or 0x03
            revert("compressed public key not supported");
        }
        pubKey = _trimBytes(pubKey, 64);
    }

    function _getAuthorityKeyIdentifier(bytes calldata der, uint256 extnValuePtr)
        private
        pure
        returns (bytes memory akid)
    {
        bytes memory extValue = der.bytesAt(extnValuePtr);

        // The AUTHORITY_KEY_IDENTIFIER consists of a SEQUENCE with the following elements
        // [0] - keyIdentifier (ESSENTIAL, but OPTIONAL as per RFC 5280)
        // [1] - authorityCertIssuer (OPTIONAL as per RFC 5280)
        // [2] - authorityCertSerialNumber (OPTIONAL as per RFC 5280)
        // since we are interested in only the key identifier
        // we iterate through the sequence until we find a tag matches with [0]

        uint256 parentPtr = extValue.root();
        uint256 ptr = extValue.firstChildOf(parentPtr);
        bytes1 contextTag = 0x80;
        while (true) {
            bytes1 tag = bytes1(extValue[ptr.ixs()]);
            if (tag == contextTag) {
                akid = extValue.bytesAt(ptr);
                break;
            }

            if (ptr.ixl() < parentPtr.ixl()) {
                ptr = extValue.nextSiblingOf(ptr);
            } else {
                break;
            }
        }
    }

    function _getSubjectKeyIdentifier(bytes calldata der, uint256 extValuePtr)
        private
        pure
        returns (bytes memory skid)
    {
        // The SUBJECT_KEY_IDENTIFIER simply consists of the KeyIdentifier of Octet String type (0x04)
        // so we can return the value as it is

        // check octet string tag
        require(der[extValuePtr.ixf()] == 0x04, "keyIdentifier must be of OctetString type");
        uint8 length = uint8(bytes1(der[extValuePtr.ixf() + 1]));
        skid = der[extValuePtr.ixf() + 2:extValuePtr.ixf() + 2 + length];
    }

    function _getSignature(bytes calldata der, uint256 sigPtr) private pure returns (bytes memory sig) {
        sigPtr = der.rootOfBitStringAt(sigPtr);

        sigPtr = der.firstChildOf(sigPtr);
        bytes memory r = _trimBytes(der.bytesAt(sigPtr), 32);

        sigPtr = der.nextSiblingOf(sigPtr);
        bytes memory s = _trimBytes(der.bytesAt(sigPtr), 32);

        sig = abi.encodePacked(r, s);
    }

    /// @dev remove unnecessary prefix from the input
    function _trimBytes(bytes memory input, uint256 expectedLength) private pure returns (bytes memory output) {
        uint256 n = input.length;
        if (n == expectedLength) {
            output = input;
        } else if (n < expectedLength) {
            output = new bytes(expectedLength);
            uint256 padLength = expectedLength - n;
            for (uint256 i = 0; i < n; i++) {
                output[padLength + i] = input[i];
            }
        } else {
            uint256 lengthDiff = n - expectedLength;
            output = input.substring(lengthDiff, expectedLength);
        }
    }

    function _getExtensionPtr(bytes calldata der) private pure returns (uint256 extensionPtr) {
        uint256 root = der.root();
        uint256 tbsParentPtr = der.firstChildOf(root);
        extensionPtr = der.firstChildOf(tbsParentPtr);
        // iterate through the sequence until we find the extension tag (0xA3)
        while (extensionPtr.ixl() <= tbsParentPtr.ixl()) {
            bytes1 tag = bytes1(der[extensionPtr.ixs()]);
            if (tag == 0xA3) {
                return extensionPtr;
            } else {
                if (extensionPtr.ixl() == tbsParentPtr.ixl()) {
                    revert("Extension is missing");
                } else {
                    extensionPtr = der.nextSiblingOf(extensionPtr);
                }
            }
        }
    }

    function _findExtensionValuePtr(bytes calldata der, uint256 extensionPtr, bytes memory oid)
        private
        pure
        returns (uint256)
    {
        uint256 parentPtr = der.firstChildOf(extensionPtr);
        uint256 ptr = der.firstChildOf(parentPtr);

        while (ptr != 0) {
            uint256 oidPtr = der.firstChildOf(ptr);
            if (der[oidPtr.ixs()] != 0x06) {
                revert("Missing OID");
            }
            if (BytesUtils.compareBytes(der.bytesAt(oidPtr), oid)) {
                return der.nextSiblingOf(oidPtr);
            }

            if (ptr.ixl() < parentPtr.ixl()) {
                ptr = der.nextSiblingOf(ptr);
            } else {
                ptr = 0;
            }
        }

        return 0; // not found
    }
}
