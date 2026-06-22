// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BytesUtils, P256Verifier} from "../utils/P256Verifier.sol";
import {PCKCollateral, PCKCertTCB} from "../types/CommonStruct.sol";
import {IPCCSRouter} from "../interfaces/IPCCSRouter.sol";

import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";
import {PCKHelper, X509CertObj} from "@automata-network/on-chain-pccs/helpers/PCKHelper.sol";
import {X509CRLHelper} from "@automata-network/on-chain-pccs/helpers/X509CRLHelper.sol";
import {CA} from "@automata-network/on-chain-pccs/Common.sol";

abstract contract X509ChainBase is P256Verifier {
    using BytesUtils for bytes;
    using LibString for bytes;

    uint8 constant PCK_CERT_CHAIN_LENGTH = 3;

    string constant PLATFORM_ISSUER_NAME = "Intel SGX PCK Platform CA";
    string constant PROCESSOR_ISSUER_NAME = "Intel SGX PCK Processor CA";

    // keccak256(hex"0ba9c4c0c0c86193a3fe23d6b02cda10a8bbd4e88e48b4458561a36e705525f567918e2edc88e40d860bd0cc4ee26aacc988e505a953558c453f6b0904ae7394")
    // the uncompressed (0x04) prefix is not included in the pubkey pre-image
    bytes32 constant ROOTCA_PUBKEY_HASH = 0x89f72d7c488e5b53a77c23ebcb36970ef7eb5bcf6658e9b8292cfbe4703a8473;

    // === PEM PARSER CONSTANTS ===
    string constant X509_HEADER = "-----BEGIN CERTIFICATE-----";
    string constant X509_FOOTER = "-----END CERTIFICATE-----";
    uint256 constant X509_HEADER_LENGTH = 27;
    uint256 constant X509_FOOTER_LENGTH = 25;

    function getPckCollateral(address pckHelperAddr, uint16 certType, bytes memory rawCertData)
        internal
        pure
        returns (bool success, PCKCollateral memory pck)
    {
        pck.pckChain = new X509CertObj[](3);

        if (certType == 5) {
            bytes[] memory certArray;
            (success, certArray) = _splitCertificateChain(rawCertData, 3);
            if (!success) {
                return (false, pck);
            }
            (pck.pckChain[0], pck.pckExtension) = _parsePck(pckHelperAddr, certArray[0]);

            bytes[] memory issuerChain = new bytes[](certArray.length - 1);
            for (uint256 a = 0; a < issuerChain.length; a++) {
                issuerChain[a] = certArray[a + 1];
            }

            X509CertObj[] memory parsedIssuerChain = _parsePckIssuer(pckHelperAddr, issuerChain);
            for (uint256 i = 0; i < parsedIssuerChain.length; i++) {
                pck.pckChain[i + 1] = parsedIssuerChain[i];
            }
        } else {
            return (false, pck);
        }
    }

    function verifyCertChain(IPCCSRouter pccsRouter, address crlHelperAddr, X509CertObj[] memory certs)
        internal
        view
        returns (bool)
    {
        require(certs.length == PCK_CERT_CHAIN_LENGTH, "Invalid PCK certificate chain length");

        X509CRLHelper crlHelper = X509CRLHelper(crlHelperAddr);
        bool certRevoked;
        bool certNotExpired;
        bool verified;
        bool certChainCanBeTrusted;
        for (uint256 i = 0; i < PCK_CERT_CHAIN_LENGTH; i++) {
            X509CertObj memory current = certs[i];
            X509CertObj memory issuer;
            bytes memory crl;
            if (i == PCK_CERT_CHAIN_LENGTH - 1) {
                // the last cert must be the root CA
                issuer = certs[i];
                bytes32 issuerPubKeyHash = keccak256(issuer.subjectPublicKey);
                certChainCanBeTrusted = issuerPubKeyHash == ROOTCA_PUBKEY_HASH;
                if (!certChainCanBeTrusted) {
                    break;
                }
            } else {
                issuer = certs[i + 1];
                if (i == PCK_CERT_CHAIN_LENGTH - 2) {
                    crl = pccsRouter.getCrl(CA.ROOT);
                } else if (i == 0) {
                    string memory issuerName = current.issuerCommonName;
                    if (LibString.eq(issuerName, PLATFORM_ISSUER_NAME)) {
                        crl = pccsRouter.getCrl(CA.PLATFORM);
                    } else if (LibString.eq(issuerName, PROCESSOR_ISSUER_NAME)) {
                        crl = pccsRouter.getCrl(CA.PROCESSOR);
                    } else {
                        return false;
                    }
                }
            }

            bytes memory issuerSubjectKeyIdentifier = issuer.subjectKeyIdentifier;

            if (crl.length > 0) {
                // check issuer subject key identifier against crl authority key identifier
                bytes memory crlAuthorityKeyIdentifier = crlHelper.getAuthorityKeyIdentifier(crl);
                if (!BytesUtils.compareBytes(issuerSubjectKeyIdentifier, crlAuthorityKeyIdentifier)) {
                    return false;
                }
                certRevoked = crlHelper.serialNumberIsRevoked(current.serialNumber, crl);
            }
            if (certRevoked) {
                break;
            }

            certNotExpired = block.timestamp > current.validityNotBefore && block.timestamp < current.validityNotAfter;
            if (!certNotExpired) {
                break;
            }

            {
                bytes memory currentAuthorityKeyIdentifier = current.authorityKeyIdentifier;
                if (BytesUtils.compareBytes(issuerSubjectKeyIdentifier, currentAuthorityKeyIdentifier)) {
                    verified = ecdsaVerify(sha256(current.tbs), current.signature, issuer.subjectPublicKey);
                }
                if (!verified) {
                    break;
                }
            }
        }
        return !certRevoked && certNotExpired && verified && certChainCanBeTrusted;
    }

    function _parsePck(address pckHelperAddr, bytes memory pckDer)
        private
        pure
        returns (X509CertObj memory pck, PCKCertTCB memory extension)
    {
        PCKHelper pckHelper = PCKHelper(pckHelperAddr);
        pck = pckHelper.parseX509DER(pckDer);
        (extension.pcesvn, extension.cpusvns, extension.fmspcBytes, extension.pceidBytes) =
            pckHelper.parsePckExtension(pckDer, pck.extensionPtr);
    }

    function _parsePckIssuer(address pckHelperAddr, bytes[] memory issuerChain)
        private
        pure
        returns (X509CertObj[] memory chain)
    {
        PCKHelper pckHelper = PCKHelper(pckHelperAddr);
        uint256 n = issuerChain.length;
        chain = new X509CertObj[](n);
        for (uint256 i = 0; i < n; i++) {
            chain[i] = pckHelper.parseX509DER(issuerChain[i]);
        }
    }

    function _splitCertificateChain(bytes memory pemChain, uint256 size)
        private
        pure
        returns (bool success, bytes[] memory certs)
    {
        certs = new bytes[](size);
        string memory pemChainStr = string(pemChain);

        uint256 index = 0;
        uint256 len = pemChain.length;

        for (uint256 i = 0; i < size; i++) {
            string memory input;
            if (i > 0) {
                input = LibString.slice(pemChainStr, index, index + len);
            } else {
                input = pemChainStr;
            }
            uint256 increment;
            (success, certs[i], increment) = _removeHeadersAndFooters(input);
            certs[i] = Base64.decode(string(certs[i]));

            if (!success) {
                return (false, certs);
            }

            index += increment;
        }

        success = true;
    }

    function _removeHeadersAndFooters(string memory pemData)
        private
        pure
        returns (bool success, bytes memory extracted, uint256 endIndex)
    {
        // Check if the input contains the "BEGIN" and "END" headers
        uint256 beginPos = LibString.indexOf(pemData, X509_HEADER);
        uint256 endPos = LibString.indexOf(pemData, X509_FOOTER);

        bool headerFound = beginPos != LibString.NOT_FOUND;
        bool footerFound = endPos != LibString.NOT_FOUND;

        if (!headerFound || !footerFound) {
            return (false, extracted, endIndex);
        }

        // Extract the content between the headers
        uint256 contentStart = beginPos + X509_HEADER_LENGTH;

        // Extract and return the content
        bytes memory contentBytes;

        // do not include newline
        bytes memory delimiter = hex"0a";
        string memory contentSlice = LibString.slice(pemData, contentStart, endPos);
        string[] memory split = LibString.split(contentSlice, string(delimiter));
        string memory contentStr;

        for (uint256 i = 0; i < split.length; i++) {
            contentStr = LibString.concat(contentStr, split[i]);
        }

        contentBytes = bytes(contentStr);
        return (true, contentBytes, endPos + X509_FOOTER_LENGTH);
    }
}
