//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TCBStatus} from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";
import {X509CertObj} from "@automata-network/on-chain-pccs/helpers/X509Helper.sol";

/**
 * @title CommonStruct
 * @notice Structs that are common across different versions and TEE of Intel DCAP Quote
 * @dev May refer to Intel Official Documentation for more details on the struct definition
 * @dev Intel V3 SGX DCAP API Library: https://download.01.org/intel-sgx/sgx-dcap/1.22/linux/docs/Intel_SGX_ECDSA_QuoteLibReference_DCAP_API.pdf
 * @dev Intel V4 TDX DCAP API Library: https://download.01.org/intel-sgx/sgx-dcap/1.22/linux/docs/Intel_TDX_DCAP_Quoting_Library_API.pdf
 * @dev Fields that are declared as integers (uint*) must reverse the byte order to big-endian
 * @dev Fields declared as `bytes*` types retain their byte order and do not require conversion
 */

/**
 * @notice The Quote Header struct definition
 * @dev https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationLibrary/blob/16b7291a7a86e486fdfcf1dfb4be885c0cc00b4e/Src/AttestationLibrary/src/QuoteVerification/QuoteStructures.h#L42-L53
 * @dev Section A.3 of Intel V4 TDX DCAP API Library Documentation
 */
struct Header {
    uint16 version; // LE -> BE
    bytes2 attestationKeyType;
    bytes4 teeType;
    bytes2 qeSvn;
    bytes2 pceSvn;
    bytes16 qeVendorId;
    bytes20 userData;
}

/**
 * @notice The struct definition of EnclaveReport
 * @notice The Quoting Enclave (QE) Report uses this struct
 * @notice Both v3 and v4 Intel SGX Quotes use this struct as the quote body
 * @dev https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationLibrary/blob/16b7291a7a86e486fdfcf1dfb4be885c0cc00b4e/Src/AttestationLibrary/src/QuoteVerification/QuoteStructures.h#L63-L80
 * @dev Table 5 in Section A.4 of Intel V3 SGX DCAP API Library Documentation
 * @dev Section A.3.10 of Intel V4 TDX DCAP API Library Documentation
 */
struct EnclaveReport {
    bytes16 cpuSvn;
    bytes4 miscSelect;
    bytes28 reserved1;
    bytes16 attributes;
    bytes32 mrEnclave;
    bytes32 reserved2;
    bytes32 mrSigner;
    bytes reserved3; // 96 bytes
    uint16 isvProdId; // LE -> BE
    uint16 isvSvn; // LE -> BE
    bytes reserved4; // 60 bytes
    bytes reportData; // 64 bytes - For QEReports, this contains sha256(attestation key || QEAuthData) || bytes32(0)
}

/**
 * @notice The struct definition of QE Authentication Data
 * @dev Table 8 in Section A.4 of Intel V3 SGX DCAP API Library Documentation
 * @dev Section A.4.9 of Intel V4 TDX DCAP API Library Documentation
 * @dev https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationLibrary/blob/16b7291a7a86e486fdfcf1dfb4be885c0cc00b4e/Src/AttestationLibrary/src/QuoteVerification/QuoteStructures.h#L128-L133
 */
struct QEAuthData {
    uint16 parsedDataSize; // LE -> BE
    bytes data;
}

/**
 * @notice The struct definition of QE Certification Data
 * @dev Table 9 in Section A.4 of Intel V3 SGX DCAP API Library Documentation
 * @dev Section A.4.11 of Intel V4 TDX DCAP API Library Documentation
 * @dev The Solidity implementation only supports certType == 5
 * @dev Hence, we can safely contain the certification data as a parsed struct, rather than a raw byte array
 * @dev Modified from https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationLibrary/blob/16b7291a7a86e486fdfcf1dfb4be885c0cc00b4e/Src/AttestationLibrary/src/QuoteVerification/QuoteStructures.h#L135-L141
 */
struct CertificationData {
    uint16 certType; // LE -> BE
    uint32 certDataSize; // LE -> BE
    PCKCollateral pck;
}

/// ========== CUSTOM TYPES ==========
/// Custom types that are not defined in the Intel DCAP API Library, but are used in the contract

struct AuthData {
    bytes ecdsa256BitSignature;
    bytes ecdsaAttestationKey;
    bytes qeReport;
    bytes qeReportSignature;
    bytes qeAuthData;
    PCKCollateral certification;
}

/**
 * @title PCK Certificate Collateral
 * @param pckChain The Parsed PCK Certificate Chain
 * @param pckExtension Parsed Intel SGX Extension from the PCK Certificate
 */
struct PCKCollateral {
    X509CertObj[] pckChain;
    PCKCertTCB pckExtension;
}

/**
 * @title PCK Platform TCB
 * @notice These are the TCB values extracted from the PCK Certificate extension
 */
struct PCKCertTCB {
    uint16 pcesvn;
    uint8[] cpusvns;
    bytes fmspcBytes;
    bytes pceidBytes;
}

/// TCB Status Enumeration
/// 0: OK
/// 1: TCB_SW_HARDENING_NEEDED
/// 2: TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED
/// 3: TCB_CONFIGURATION_NEEDED
/// 4: TCB_OUT_OF_DATE
/// 5: TCB_OUT_OF_DATE_CONFIGURATION_NEEDED
/// 6: TCB_REVOKED
/// 7: TCB_UNRECOGNIZED
/// 8: TCB_TD_RELAUNCH_ADVISED
/// 9: TCB_TD_RELAUNCH_ADVISED_CONFIGURATION_NEEDED

/**
 * @title Verified Output struct
 * @notice The output returned by the contract upon successful verification of the quote
 * @param quoteVersion The version of the quote
 * @param quoteBodyType The quote body type, 1. SGX Enclave Report, 2. TD1.0 Report, 3. TD1.5 Report
 * @param tcbStatus The TCB status of the quote
 * @param fmspcBytes The FMSPC values
 * @param quoteBody This can either be the Local ISV Report or TD10 Report, depending on the TEE type
 * @param advisoryIDs The list of advisory IDs returned by the matching FMSPC TCB entry
 */
struct Output {
    uint16 quoteVersion; // serialized as BE, for EVM compatibility
    uint16 quoteBodyType; // serialized as BE, for EVM compatibility
    uint8 tcbStatus;
    bytes6 fmspcBytes;
    bytes quoteBody;
    string[] advisoryIDs;
}
