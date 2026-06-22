//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TCBStatus, TcbId} from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";
import {EnclaveId} from "@automata-network/on-chain-pccs/helpers/EnclaveIdentityHelper.sol";

import {IQuoteVerifier, IPCCSRouter} from "../interfaces/IQuoteVerifier.sol";
import {BytesUtils} from "../utils/BytesUtils.sol";
import {BELE} from "../utils/BELE.sol";
import {P256Verifier} from "../utils/P256Verifier.sol";

import "../types/CommonStruct.sol";
import "../types/Constants.sol";
import "../types/Errors.sol";

import "./EnclaveIdBase.sol";
import "./X509ChainBase.sol";

struct VerificationResult {
    bool success;
    string reason;
    EnclaveIdTcbStatus qeTcbStatus;
    uint32 tcbEvalNumber;
}

abstract contract QuoteVerifierBase is IQuoteVerifier, EnclaveIdBase, X509ChainBase {
    using BytesUtils for bytes;

    IPCCSRouter public immutable override pccsRouter;
    uint16 public immutable override quoteVersion;

    constructor(address _router, uint16 _version) {
        pccsRouter = IPCCSRouter(_router);
        quoteVersion = _version;
    }

    function verifyZkOutput(bytes calldata outputBytes, uint32 tcbEvalNumber)
        public
        view
        virtual
        override
        returns (bool success, bytes memory output)
    {
        uint16 outputLength = uint16(bytes2(outputBytes[0:2]));
        uint256 offset = 2 + outputLength;
        if (offset + VERIFIED_OUTPUT_COLLATERAL_HASHES_LENGTH != outputBytes.length) {
            return (false, bytes(OUTS));
        }
        bytes memory errorMessage;
        (success, errorMessage) = checkCollateralHashes(tcbEvalNumber, offset, outputBytes);
        output = success ? outputBytes[2:offset] : errorMessage;
    }

    function _verifyQuoteIntegrity(
        uint256 pcsApiVersion,
        uint32 tcbEvalNumber,
        bytes4 tee,
        bytes memory rawHeader,
        bytes memory rawBody,
        AuthData memory authData
    ) internal view returns (VerificationResult memory result) {
        TcbId tcbId = tee == SGX_TEE ? TcbId.SGX : TcbId.TDX;

        if (tcbEvalNumber == 0) {
            tcbEvalNumber = pccsRouter.getStandardTcbEvaluationDataNumber(tcbId);
        }
        result.tcbEvalNumber = tcbEvalNumber;

        // Step 0: Check QE Report Data
        (bool parsedQeReport, EnclaveReport memory qeReport) = parseEnclaveReport(authData.qeReport);
        if (!parsedQeReport) {
            result.success = false;
            result.reason = QEF;
            return result;
        }
        result.success =
            verifyQeReportData(
                qeReport.reportData, 
                authData.ecdsaAttestationKey, 
                authData.qeAuthData
            );
        if (!result.success) {
            result.reason = QEVE;
            return result;
        }

        // Step 1: Fetch QEIdentity to validate TCB of the QE
        EnclaveId id = tee == SGX_TEE ? EnclaveId.QE : EnclaveId.TD_QE;
        (result.success, result.qeTcbStatus) = fetchQeIdentityAndCheckQeReport(id, pcsApiVersion, qeReport, tcbEvalNumber);
        if (!result.success || result.qeTcbStatus == EnclaveIdTcbStatus.SGX_ENCLAVE_REPORT_ISVSVN_REVOKED) {
            result.reason = QEIDVE;
            return result;
        }

        // Step 2: verify cert chain
        result.success = verifyCertChain(pccsRouter, pccsRouter.crlHelperAddr(), authData.certification.pckChain);
        if (!result.success) {
            result.reason = X509VE;
            return result;
        }

        // Step 3: Signature Verification on local isv report and qereport
        bytes memory localAttestationData = abi.encodePacked(rawHeader, rawBody);
        result.success = attestationVerification(
            authData.qeReport,
            authData.qeReportSignature,
            authData.certification.pckChain[0].subjectPublicKey,
            localAttestationData,
            authData.ecdsa256BitSignature,
            authData.ecdsaAttestationKey
        );
        if (!result.success) {
            result.reason = ATTVE;
            return result;
        }
    }

    function validateHeader(Header calldata header, uint256 quoteLength, bool teeIsValid)
        internal
        view
        returns (bool valid, string memory reason)
    {
        if (quoteLength < MINIMUM_QUOTE_LENGTH) {
            return (false, QHS);
        }

        if (header.version != quoteVersion) {
            return (false, QHV);
        }

        if (header.attestationKeyType != SUPPORTED_ATTESTATION_KEY_TYPE) {
            return (false, QHATTF);
        }

        if (!teeIsValid) {
            return (false, TEE);
        }

        if (header.qeVendorId != VALID_QE_VENDOR_ID) {
            return (false, QEVEN);
        }

        valid = true;
    }

    function parseEnclaveReport(bytes memory rawEnclaveReport)
        internal
        pure
        returns (bool success, EnclaveReport memory enclaveReport)
    {
        if (rawEnclaveReport.length != ENCLAVE_REPORT_LENGTH) {
            return (false, enclaveReport);
        }
        enclaveReport.cpuSvn = bytes16(rawEnclaveReport.substring(0, 16));
        enclaveReport.miscSelect = bytes4(rawEnclaveReport.substring(16, 4));
        enclaveReport.reserved1 = bytes28(rawEnclaveReport.substring(20, 28));
        enclaveReport.attributes = bytes16(rawEnclaveReport.substring(48, 16));
        enclaveReport.mrEnclave = bytes32(rawEnclaveReport.substring(64, 32));
        enclaveReport.reserved2 = bytes32(rawEnclaveReport.substring(96, 32));
        enclaveReport.mrSigner = bytes32(rawEnclaveReport.substring(128, 32));
        enclaveReport.reserved3 = rawEnclaveReport.substring(160, 96);
        enclaveReport.isvProdId = uint16(BELE.leBytesToBeUint(rawEnclaveReport.substring(256, 2)));
        enclaveReport.isvSvn = uint16(BELE.leBytesToBeUint(rawEnclaveReport.substring(258, 2)));
        enclaveReport.reserved4 = rawEnclaveReport.substring(260, 60);
        enclaveReport.reportData = rawEnclaveReport.substring(320, 64);
        success = true;
    }

    function fetchQeIdentityAndCheckQeReport(EnclaveId id, uint256 pcsApiVersion, EnclaveReport memory qeReport, uint32 tcbEvalNumber)
        internal
        view
        returns (bool success, EnclaveIdTcbStatus qeTcbStatus)
    {
        IdentityObj memory qeIdentity = pccsRouter.getQeIdentity(id, pcsApiVersion, tcbEvalNumber);
        (success, qeTcbStatus) = verifyQEReportWithIdentity(
            qeIdentity, qeReport.miscSelect, qeReport.attributes, qeReport.mrSigner, qeReport.isvProdId, qeReport.isvSvn
        );
    }

    function verifyQeReportData(bytes memory qeReportData, bytes memory attestationKey, bytes memory qeAuthData)
        internal
        pure
        returns (bool)
    {
        bytes32 expectedHash = bytes32(qeReportData);
        bytes memory preimage = abi.encodePacked(attestationKey, qeAuthData);
        bytes32 computedHash = sha256(preimage);
        return expectedHash == computedHash;
    }

    function attestationVerification(
        bytes memory rawQeReport,
        bytes memory qeSignature,
        bytes memory pckPubkey,
        bytes memory signedAttestationData,
        bytes memory attestationSignature,
        bytes memory attestationKey
    ) internal view returns (bool) {
        bool qeReportVerified = P256Verifier.ecdsaVerify(sha256(rawQeReport), qeSignature, pckPubkey);
        if (!qeReportVerified) {
            return false;
        }
        bool attestationVerified =
            P256Verifier.ecdsaVerify(sha256(signedAttestationData), attestationSignature, attestationKey);
        return attestationVerified;
    }

    // https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationLibrary/blob/16b7291a7a86e486fdfcf1dfb4be885c0cc00b4e/Src/AttestationLibrary/src/Verifiers/QuoteVerifier.cpp#L271-L312
    function convergeTcbStatusWithQeTcbStatus(EnclaveIdTcbStatus qeTcbStatus, TCBStatus tcbStatus)
        internal
        pure
        returns (TCBStatus convergedStatus)
    {
        convergedStatus = tcbStatus;
        if (qeTcbStatus == EnclaveIdTcbStatus.SGX_ENCLAVE_REPORT_ISVSVN_OUT_OF_DATE) {
            if (tcbStatus == TCBStatus.OK || tcbStatus == TCBStatus.TCB_SW_HARDENING_NEEDED) {
                convergedStatus = TCBStatus.TCB_OUT_OF_DATE;
            }
            if (
                tcbStatus == TCBStatus.TCB_CONFIGURATION_NEEDED
                    || tcbStatus == TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED
            ) {
                convergedStatus = TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED;
            }
        }
    }

    function serializeOutput(Output memory output) internal pure returns (bytes memory) {
        return abi.encodePacked(
            output.quoteVersion,
            output.quoteBodyType,
            output.tcbStatus,
            output.fmspcBytes,
            output.quoteBody,
            output.advisoryIDs.length > 0 ? abi.encode(output.advisoryIDs) : bytes("")
        );
    }

    function checkCollateralHashes(uint32 tcbEvalNumber, uint256 offset, bytes calldata zkOutput)
        internal
        view
        returns (bool, bytes memory)
    {
        uint64 timestamp = uint64(bytes8(zkOutput[offset:offset + 8]));
        bytes32 tcbInfoContentHash = bytes32(zkOutput[offset + 8:offset + 40]);
        bytes32 identityContentHash = bytes32(zkOutput[offset + 40:offset + 72]);
        bytes32 rootCaHash = bytes32(zkOutput[offset + 72:offset + 104]);
        bytes32 tcbSigningHash = bytes32(zkOutput[offset + 104:offset + 136]);
        bytes32 rootCaCrlHash = bytes32(zkOutput[offset + 136:offset + 168]);
        bytes32 pckCrlHash = bytes32(zkOutput[offset + 168:offset + 200]);

        uint16 quoteBodyType = uint16(bytes2(zkOutput[4:6]));
        bytes6 fmspc = bytes6(zkOutput[7:13]);
        bool isSGX = quoteBodyType == 1;

        TcbId tcbId = isSGX ? TcbId.SGX : TcbId.TDX;

        if (tcbEvalNumber == 0) {
            // if tcbEvalNumber is not provided, we use the standard one
            tcbEvalNumber = pccsRouter.getStandardTcbEvaluationDataNumberWithTimestamp(tcbId, timestamp);
        }

        bytes32 expectedTcbInfoContentHash =
            pccsRouter.getFmspcTcbContentHashWithTimestamp(tcbId, fmspc, quoteVersion < 4 ? 2 : 3, tcbEvalNumber, timestamp);
        if (tcbInfoContentHash != expectedTcbInfoContentHash) {
            return (false, bytes(TCBCH));
        }

        uint32 pcsApiVersion = quoteVersion < 4 ? 3 : 4;
        bytes32 expectedIdentityContentHash = pccsRouter.getQeIdentityContentHashWithTimestamp(
            isSGX ? EnclaveId.QE : EnclaveId.TD_QE, pcsApiVersion, tcbEvalNumber, timestamp
        );
        if (identityContentHash != expectedIdentityContentHash) {
            return (false, bytes(QEIDCH));
        }

        bytes32 expectedRootCaHash = pccsRouter.getCertHashWithTimestamp(CA.ROOT, timestamp);
        if (rootCaHash != expectedRootCaHash) {
            return (false, bytes(ROOTH));
        }
        bytes32 expectedTcbSigningHash = pccsRouter.getCertHashWithTimestamp(CA.SIGNING, timestamp);
        if (tcbSigningHash != expectedTcbSigningHash) {
            return (false, bytes(SIGNH));
        }
        bytes32 expectedRootCrlHash = pccsRouter.getCrlHashWithTimestamp(CA.ROOT, timestamp);
        if (rootCaCrlHash != expectedRootCrlHash) {
            return (false, bytes(ROOTCRLH));
        }

        // use low level calls for PCK CRLs, because we don't know which one of the CAs is used
        // to verify the quote
        // we can catch reverts here, and consider it a valid quote as long as:
        // - one of the PCK CAs has a CRL stored on-chain
        // - the hash of the on-chain CRL matches with the CRL hash in the zkOutput

        (bool platformSuccess, bytes memory platformRet) = address(pccsRouter).staticcall(
            abi.encodeWithSelector(IPCCSRouter.getCrlHashWithTimestamp.selector, CA.PLATFORM, timestamp)
        );

        (bool processorSuccess, bytes memory processorRet) = address(pccsRouter).staticcall(
            abi.encodeWithSelector(IPCCSRouter.getCrlHashWithTimestamp.selector, CA.PROCESSOR, timestamp)
        );

        bytes32 expectedPlatformCrlHash;
        bytes32 expectedProcessorCrlHash;
        if (platformSuccess) {
            expectedPlatformCrlHash = abi.decode(platformRet, (bytes32));
        } else if (processorSuccess) {
            expectedProcessorCrlHash = abi.decode(processorRet, (bytes32));
        } else {
            // Both Processor and Platform PCKs not found
            return (false, bytes(PCKCRLM));
        }

        bool crlHashMatched = pckCrlHash == expectedPlatformCrlHash || pckCrlHash == expectedProcessorCrlHash;
        return (crlHashMatched, crlHashMatched ? bytes("") : bytes(PCKCRLH));
    }
}
