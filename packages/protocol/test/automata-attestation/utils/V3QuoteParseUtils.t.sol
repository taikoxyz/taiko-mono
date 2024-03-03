// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { V3Struct } from "../../../contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol";
import { V3Parser } from "../../../contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol";
import { IPEMCertChainLib } from
    "../../../contracts/automata-attestation/lib/interfaces/IPEMCertChainLib.sol";
import { PEMCertChainLib } from "../../../contracts/automata-attestation/lib/PEMCertChainLib.sol";
import { Base64 } from "solady/src/utils/Base64.sol";
import { JSONParserLib } from "solady/src/utils/JSONParserLib.sol";
import { LibString } from "solady/src/utils/LibString.sol";

contract V3QuoteParseUtils {
    using JSONParserLib for JSONParserLib.Item;
    using LibString for string;

    // all helper structure are ordered by alphabetical order of their field names
    // because the foundry Json decoder will decode the json string in alphabetical order
    struct HeaderHelper {
        bytes attestationKeyType;
        bytes pceSvn;
        bytes qeSvn;
        bytes qeVendorId;
        bytes teeType;
        address userData;
        bytes version;
    }

    struct EnclaveReportHelper {
        bytes attributes;
        bytes cpuSvn;
        uint256 isvProdId;
        uint256 isvSvn;
        bytes miscSelect;
        bytes32 mrEnclave;
        bytes32 mrSigner;
        bytes reportData; // 64 bytes - For QEReports, this contains the hash of the concatenation
            // of attestation key and QEAuthData
        bytes reserved1;
        bytes32 reserved2;
        bytes reserved3; // 96 bytes
        bytes reserved4; // 60 bytes
    }

    struct QEAuthDataHelper {
        bytes32 data;
        uint256 parsedDataSize;
    }

    // in case data length is 20
    struct QEAuthDataHelperAddress {
        address data;
        uint256 parsedDataSize;
    }

    // in case data length is neither 20 nor 32
    struct QEAuthDataHelperBytes {
        bytes data;
        uint256 parsedDataSize;
    }

    struct CertificationDataHelper {
        uint256 certDataSize;
        uint256 certType;
        bytes[] decodedCertDataArray;
    }

    struct ECDSAQuoteV3AuthDataHelper {
        CertificationDataHelper certification;
        bytes ecdsa256BitSignature;
        bytes ecdsaAttestationKey;
        EnclaveReportHelper pckSignedQeReport;
        QEAuthDataHelper qeAuthData;
        bytes qeReportSignature;
    }

    struct ParsedV3QuoteStructHelper {
        HeaderHelper header;
        EnclaveReportHelper localEnclaveReport;
        ECDSAQuoteV3AuthDataHelper v3AuthData;
    }

    function parseV3QuoteJson(bytes memory v3QuotePacked)
        internal
        pure
        returns (bool success, V3Struct.ParsedV3QuoteStruct memory v3quote)
    {
        success = true;
        ParsedV3QuoteStructHelper memory v3quoteHelper =
            abi.decode(v3QuotePacked, (ParsedV3QuoteStructHelper));

        // setup header
        v3quote.header.version = bytes2(v3quoteHelper.header.version);
        v3quote.header.attestationKeyType = bytes2(v3quoteHelper.header.attestationKeyType);
        v3quote.header.teeType = bytes4(v3quoteHelper.header.teeType);
        v3quote.header.qeSvn = bytes2(v3quoteHelper.header.qeSvn);
        v3quote.header.pceSvn = bytes2(v3quoteHelper.header.pceSvn);
        v3quote.header.qeVendorId = bytes16(v3quoteHelper.header.qeVendorId);
        v3quote.header.userData = bytes20(v3quoteHelper.header.userData);

        // setup localEnclaveReport
        v3quote.localEnclaveReport.cpuSvn = bytes16(v3quoteHelper.localEnclaveReport.cpuSvn);
        v3quote.localEnclaveReport.miscSelect = bytes4(v3quoteHelper.localEnclaveReport.miscSelect);
        v3quote.localEnclaveReport.reserved1 = bytes28(v3quoteHelper.localEnclaveReport.reserved1);
        v3quote.localEnclaveReport.attributes = bytes16(v3quoteHelper.localEnclaveReport.attributes);
        v3quote.localEnclaveReport.mrEnclave = v3quoteHelper.localEnclaveReport.mrEnclave;
        v3quote.localEnclaveReport.reserved2 = v3quoteHelper.localEnclaveReport.reserved2;
        v3quote.localEnclaveReport.mrSigner = v3quoteHelper.localEnclaveReport.mrSigner;
        v3quote.localEnclaveReport.reserved3 = bytes(v3quoteHelper.localEnclaveReport.reserved3);
        v3quote.localEnclaveReport.isvProdId = uint16(v3quoteHelper.localEnclaveReport.isvProdId);
        v3quote.localEnclaveReport.isvSvn = uint16(v3quoteHelper.localEnclaveReport.isvSvn);
        v3quote.localEnclaveReport.reserved4 = bytes(v3quoteHelper.localEnclaveReport.reserved4);
        v3quote.localEnclaveReport.reportData = bytes(v3quoteHelper.localEnclaveReport.reportData);

        // setup v3AuthData
        v3quote.v3AuthData.ecdsa256BitSignature =
            bytes(v3quoteHelper.v3AuthData.ecdsa256BitSignature);
        v3quote.v3AuthData.ecdsaAttestationKey = bytes(v3quoteHelper.v3AuthData.ecdsaAttestationKey);
        v3quote.v3AuthData.pckSignedQeReport = V3Struct.EnclaveReport({
            cpuSvn: bytes16(v3quoteHelper.v3AuthData.pckSignedQeReport.cpuSvn),
            miscSelect: bytes4(v3quoteHelper.v3AuthData.pckSignedQeReport.miscSelect),
            reserved1: bytes28(v3quoteHelper.v3AuthData.pckSignedQeReport.reserved1),
            attributes: bytes16(v3quoteHelper.v3AuthData.pckSignedQeReport.attributes),
            mrEnclave: v3quoteHelper.v3AuthData.pckSignedQeReport.mrEnclave,
            reserved2: v3quoteHelper.v3AuthData.pckSignedQeReport.reserved2,
            mrSigner: v3quoteHelper.v3AuthData.pckSignedQeReport.mrSigner,
            reserved3: bytes(v3quoteHelper.v3AuthData.pckSignedQeReport.reserved3),
            isvProdId: uint16(v3quoteHelper.v3AuthData.pckSignedQeReport.isvProdId),
            isvSvn: uint16(v3quoteHelper.v3AuthData.pckSignedQeReport.isvSvn),
            reserved4: bytes(v3quoteHelper.v3AuthData.pckSignedQeReport.reserved4),
            reportData: bytes(v3quoteHelper.v3AuthData.pckSignedQeReport.reportData)
        });
        v3quote.v3AuthData.qeReportSignature = bytes(v3quoteHelper.v3AuthData.qeReportSignature);
        v3quote.v3AuthData.qeAuthData = V3Struct.QEAuthData({
            parsedDataSize: uint16(v3quoteHelper.v3AuthData.qeAuthData.parsedDataSize),
            data: bytes.concat(v3quoteHelper.v3AuthData.qeAuthData.data)
        });
        v3quote.v3AuthData.certification = V3Struct.CertificationData({
            certType: uint16(v3quoteHelper.v3AuthData.certification.certType),
            certDataSize: uint32(v3quoteHelper.v3AuthData.certification.certDataSize),
            decodedCertDataArray: [
                v3quoteHelper.v3AuthData.certification.decodedCertDataArray[0],
                v3quoteHelper.v3AuthData.certification.decodedCertDataArray[1],
                v3quoteHelper.v3AuthData.certification.decodedCertDataArray[2]
            ]
        });
    }

    function ParseV3QuoteBytes(
        address pemCertChainLib,
        bytes memory v3QuoteBytes
    )
        public
        pure
        returns (V3Struct.ParsedV3QuoteStruct memory v3quote)
    {
        bool successful = false;
        (successful, v3quote) = V3Parser.parseInput(v3QuoteBytes, pemCertChainLib);
        require(successful, "V3Quote bytes parse failed");
    }
}
