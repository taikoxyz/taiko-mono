// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Asn1Decode, NodePtr} from "../utils/Asn1Decode.sol";
import {BytesUtils} from "../utils/BytesUtils.sol";
import {DateTimeUtils} from "../utils/DateTimeUtils.sol";

/**
 * @title Solidity Structure representing X509 CRL
 * @notice This is a simplified structure of a DER-decoded X509 CRL
 */
struct X509CRLObj {
    string issuerCommonName;
    uint256 validityNotBefore;
    uint256 validityNotAfter;
    uint256[] serialNumbersRevoked;
    bytes authorityKeyIdentifier;
    // for signature verification in the cert chain
    bytes signature;
    bytes tbs;
}

/**
 * @title X509 CRL Helper Contract
 * @notice This is a standalone contract that can be used by off-chain applications and smart contracts
 * to parse DER-encoded CRLs.
 * @dev This parser is only valid for ECDSA signature algorithm and p256 key algorithm.
 */
contract X509CRLHelper {
    using Asn1Decode for bytes;
    using NodePtr for uint256;
    using BytesUtils for bytes;

    // 2.5.4.3
    bytes constant COMMON_NAME_OID = hex"550403";
    // 2.5.29.20
    bytes constant CRL_NUMBER_OID = hex"551d14";
    // 2.5.29.35
    bytes constant AUTHORITY_KEY_IDENTIFIER_OID = hex"551D23";

    /// =================================================================================
    /// USE THE GETTERS BELOW IF YOU DON'T WANT TO PARSE THE ENTIRE X509 CRL
    /// =================================================================================

    function getTbsAndSig(bytes calldata der) external pure returns (bytes memory tbs, bytes memory sig) {
        uint256 root = der.root();
        uint256 tbsParentPtr = der.firstChildOf(root);
        uint256 sigPtr = der.nextSiblingOf(tbsParentPtr);
        sigPtr = der.nextSiblingOf(sigPtr);

        tbs = der.allBytesAt(tbsParentPtr);
        sig = _getSignature(der, sigPtr);
    }

    function getIssuerCommonName(bytes calldata der) external pure returns (string memory issuerCommonName) {
        uint256 root = der.root();
        uint256 tbsParentPtr = der.firstChildOf(root);
        uint256 tbsPtr = der.firstChildOf(tbsParentPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        issuerCommonName = _getCommonName(der, tbsPtr);
    }

    function getCrlValidity(bytes calldata der)
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
        (validityNotBefore, validityNotAfter) = _getValidity(der, tbsPtr);
    }

    function serialNumberIsRevoked(uint256 serialNumber, bytes calldata der) external pure returns (bool revoked) {
        uint256 root = der.root();
        uint256 tbsParentPtr = der.firstChildOf(root);
        uint256 tbsPtr = der.firstChildOf(tbsParentPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);
        if (bytes1(der[tbsPtr.ixs()]) == 0x30) {
            uint256[] memory ret = _getRevokedSerialNumbers(der, tbsPtr, true, serialNumber);
            revoked = ret[0] == serialNumber;
        }
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

    /// x509 CRL generally contain a sequence of elements in the following order:
    /// 1. tbs
    /// - 1a. serial number
    /// - 1b. signature algorithm
    /// - 1c. issuer
    /// - - 1c(a). common name
    /// - - 1c(b). organization name
    /// - - 1c(c). locality name
    /// - - 1c(d). state or province name
    /// - - 1c(e). country name
    /// - 1d. not before
    /// - 1e. not after
    /// - 1f. revoked certificates
    /// - - A list consists of revoked serial numbers and reasons.
    /// - 1g. CRL extensions
    /// - - 1g(a) CRL number
    /// - - 1g(b) Authority Key Identifier
    /// 2. Signature Algorithm
    /// 3. Signature
    function parseCRLDER(bytes calldata der) external pure returns (X509CRLObj memory crl) {
        uint256 root = der.root();

        uint256 tbsParentPtr = der.firstChildOf(root);
        crl.tbs = der.allBytesAt(tbsParentPtr);

        uint256 tbsPtr = der.firstChildOf(tbsParentPtr);

        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);

        crl.issuerCommonName = _getCommonName(der, tbsPtr);

        tbsPtr = der.nextSiblingOf(tbsPtr);
        (crl.validityNotBefore, crl.validityNotAfter) = _getValidity(der, tbsPtr);

        tbsPtr = der.nextSiblingOf(tbsPtr);
        tbsPtr = der.nextSiblingOf(tbsPtr);

        if (bytes1(der[tbsPtr.ixs()]) == 0x30) {
            // the revoked certificates field is present
            crl.serialNumbersRevoked = _getRevokedSerialNumbers(der, tbsPtr, false, 0);
            tbsPtr = der.nextSiblingOf(tbsPtr);
        }

        if (bytes1(der[tbsPtr.ixs()]) == 0xA0) {
            uint256 authorityKeyIdentifierPtr = _findExtensionValuePtr(der, tbsPtr, AUTHORITY_KEY_IDENTIFIER_OID);
            if (authorityKeyIdentifierPtr != 0) {
                crl.authorityKeyIdentifier = _getAuthorityKeyIdentifier(der, authorityKeyIdentifierPtr);
            }
        } else {
            revert("Extension is missing");
        }

        // tbs iteration completed
        // now we just need to look for the signature

        uint256 sigPtr = der.nextSiblingOf(tbsParentPtr);
        sigPtr = der.nextSiblingOf(sigPtr);
        crl.signature = _getSignature(der, sigPtr);
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
        uint256 notBeforePtr = validityPtr;
        uint256 notAfterPtr = der.nextSiblingOf(notBeforePtr);
        notBefore = DateTimeUtils.fromDERToTimestamp(der.bytesAt(notBeforePtr));
        notAfter = DateTimeUtils.fromDERToTimestamp(der.bytesAt(notAfterPtr));
    }

    function _getRevokedSerialNumbers(bytes calldata der, uint256 revokedParentPtr, bool breakIfFound, uint256 filter)
        private
        pure
        returns (uint256[] memory serialNumbers)
    {
        uint256 revokedPtr = der.firstChildOf(revokedParentPtr);
        bytes memory serials;
        while (revokedPtr.ixl() <= revokedParentPtr.ixl()) {
            uint256 serialPtr = der.firstChildOf(revokedPtr);
            bytes memory serialBytes = der.bytesAt(serialPtr);
            uint256 serialNumber = _parseSerialNumber(serialBytes);
            serials = abi.encodePacked(serials, serialNumber);
            if (breakIfFound && filter == serialNumber) {
                serialNumbers = new uint256[](1);
                serialNumbers[0] = filter;
                return serialNumbers;
            }
            revokedPtr = der.nextSiblingOf(revokedPtr);
        }
        uint256 count = serials.length / 32;
        // ABI encoding format for a dynamic uint256[] value
        serials = abi.encodePacked(abi.encode(0x20), abi.encode(count), serials);
        serialNumbers = new uint256[](count);
        serialNumbers = abi.decode(serials, (uint256[]));
    }

    function _parseSerialNumber(bytes memory serialBytes) private pure returns (uint256 serial) {
        uint256 shift = 8 * (32 - serialBytes.length);
        serial = uint256(bytes32(serialBytes) >> shift);
    }

    function _getSignature(bytes calldata der, uint256 sigPtr) private pure returns (bytes memory sig) {
        sigPtr = der.rootOfBitStringAt(sigPtr);

        sigPtr = der.firstChildOf(sigPtr);
        bytes memory r = _trimBytes(der.bytesAt(sigPtr), 32);

        sigPtr = der.nextSiblingOf(sigPtr);
        bytes memory s = _trimBytes(der.bytesAt(sigPtr), 32);

        sig = abi.encodePacked(r, s);
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
            if (tag == 0xA0) {
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
