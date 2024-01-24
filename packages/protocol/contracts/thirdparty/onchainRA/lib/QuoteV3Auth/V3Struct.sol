//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library V3Struct {
    struct Header {
        bytes2 version;
        bytes2 attestationKeyType;
        bytes4 teeType;
        bytes2 qeSvn;
        bytes2 pceSvn;
        bytes16 qeVendorId;
        bytes20 userData;
    }

    struct EnclaveReport {
        bytes16 cpuSvn;
        bytes4 miscSelect;
        bytes28 reserved1;
        bytes16 attributes;
        bytes32 mrEnclave;
        bytes32 reserved2;
        bytes32 mrSigner;
        bytes reserved3; // 96 bytes
        uint16 isvProdId;
        uint16 isvSvn;
        bytes reserved4; // 60 bytes
        bytes reportData; // 64 bytes - For QEReports, this contains the hash of the concatenation of attestation key and QEAuthData
    }

    struct QEAuthData {
        // avoid uint256 -> uint16 conversion to save gas
        uint256 parsedDataSize;
        bytes data;
    }

    struct ParsedQEAuthData {
        uint16 parsedDataSize;
        bytes data; // todo! data.length = parsedDataSize
    }

    struct CertificationData {
        // avoid uint256 -> uint16 conversion to save gas
        uint256 certType;
        // avoid uint256 -> uint32 conversion to save gas
        uint256 certDataSize;
        bytes certData;
    }

    struct ParsedCertificationData {
        uint16 certType;
        // avoid uint256 -> uint32 conversion to save gas
        uint32 certDataSize; // todo! certDataSize = len(join((BEGIN_CERT, certArray[i], END_CERT) for i in 0..3))
        bytes[3] decodedCertDataArray; // base64 decoded cert bytes array
    }

    struct ECDSAQuoteV3AuthData {
        bytes ecdsa256BitSignature; // 64 bytes
        bytes ecdsaAttestationKey; // 64 bytes
        bytes rawQeReport; // 384 bytes
        bytes qeReportSignature; // 64 bytes
        QEAuthData qeAuthData;
        CertificationData certification;
    }

    struct ParsedECDSAQuoteV3AuthData {
        bytes ecdsa256BitSignature; // 64 bytes
        bytes ecdsaAttestationKey; // 64 bytes
        EnclaveReport pckSignedQeReport; // 384 bytes
        bytes qeReportSignature; // 64 bytes
        ParsedQEAuthData qeAuthData;
        ParsedCertificationData certification;
    }

    struct ParsedV3QuoteStruct {
        Header header;
        EnclaveReport localEnclaveReport;
        ParsedECDSAQuoteV3AuthData v3AuthData;
    }
}
