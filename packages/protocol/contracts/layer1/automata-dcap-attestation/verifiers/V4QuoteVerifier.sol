//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibString} from "solady/utils/LibString.sol";
import {TD10ReportParser} from "../utils/TDReportParser.sol";
import {TD10ReportBody} from "../types/TDXStruct.sol";
import "../bases/TdxQuoteBase.sol";
import "../types/Errors.sol";

/**
 * @title Automata DCAP QuoteV4 Verifier
 */
contract V4QuoteVerifier is TdxQuoteBase {
    using LibString for bytes;

    constructor(address _ecdsaVerifier, address _router) QuoteVerifierBase(_router, 4) P256Verifier(_ecdsaVerifier) {}

    function verifyQuote(Header calldata header, bytes calldata rawQuote, uint32 tcbEvalNumber)
        external
        view
        override
        returns (bool success, bytes memory output)
    {
        string memory reason;
        bytes memory rawQuoteBody;
        AuthData memory authData;
        (success, reason, rawQuoteBody, authData) = _parseV4Quote(header, rawQuote);
        if (!success) {
            return (false, bytes(reason));
        }

        // we parsed the quote except for the body
        // parse body then verify quote
        bytes memory rawQuoteHeader = rawQuote[0:HEADER_LENGTH];
        if (header.teeType == SGX_TEE) {
            (success, output) = _verifySGXQuote(tcbEvalNumber, rawQuoteHeader, rawQuoteBody, authData);
        } else if (header.teeType == TDX_TEE) {
            (success, output) = _verifyTDXQuote(tcbEvalNumber, rawQuoteHeader, rawQuoteBody, authData);
        } else {
            return (false, bytes(TEE));
        }
    }

    function _parseV4Quote(Header calldata header, bytes calldata quote)
        private
        view
        returns (
            bool success,
            string memory reason,
            bytes memory rawQuoteBody,
            AuthData memory authData
        )
    {
        bytes4 teeType = header.teeType;
        (success, reason) = validateHeader(header, quote.length, teeType == SGX_TEE || teeType == TDX_TEE);
        if (!success) {
            return (success, reason, rawQuoteBody, authData);
        }

        // now that we are able to confirm that the provided quote is a valid V4 SGX/TDX quote
        // based on information found in the header
        // we continue parsing the remainder of the quote

        uint256 offset = HEADER_LENGTH;
        if (teeType == SGX_TEE) {
            offset += ENCLAVE_REPORT_LENGTH;
        } else {
            offset += TD_REPORT10_LENGTH;
        }
        rawQuoteBody = quote[HEADER_LENGTH:offset];

        if (quote.length < offset) {
            return (false, QBS, rawQuoteBody, authData);
        }

        // check authData length
        uint256 localAuthDataSize = BELE.leBytesToBeUint(quote[offset:offset + 4]);
        offset += 4;
        // we don't strictly require the auth data to be equal to the provided length
        // but this ignores any trailing bytes after the indicated length allocated for authData
        if (quote.length - offset < localAuthDataSize) {
            return (false, ADS, rawQuoteBody, authData);
        }

        // at this point, we have verified the length of the entire quote to be correct
        // parse authData
        (success, authData) = _parseAuthData(quote[offset:offset + localAuthDataSize]);
        if (!success) {
            return (false, ADF, rawQuoteBody, authData);
        }
    }

    function _verifySGXQuote(
        uint32 tcbEvalNumber,
        bytes memory rawQuoteHeader,
        bytes memory rawQuoteBody,
        AuthData memory authData
    ) private view returns (bool success, bytes memory serialized) {
        VerificationResult memory result =
            _verifyQuoteIntegrity(4, tcbEvalNumber, SGX_TEE, rawQuoteHeader, rawQuoteBody, authData);
        if (!result.success) {
            return (false, bytes(result.reason));
        }

        PCKCertTCB memory pckTcb = authData.certification.pckExtension;
        (TCBLevelsObj[] memory tcbLevels,,) =
            pccsRouter.getFmspcTcbV3(TcbId.SGX, bytes6(pckTcb.fmspcBytes), result.tcbEvalNumber);

        TCBStatus tcbStatus;
        bool statusFound;
        uint256 tcbLevelSelected;
        for (uint256 i = 0; i < tcbLevels.length; i++) {
            (statusFound, tcbStatus) = getSGXTcbStatus(pckTcb, tcbLevels[i]);
            if (statusFound) {
                tcbLevelSelected = i;
                break;
            }
        }
        if (!statusFound || tcbStatus == TCBStatus.TCB_REVOKED) {
            return (statusFound, bytes(TCBR));
        }

        tcbStatus = convergeTcbStatusWithQeTcbStatus(result.qeTcbStatus, tcbStatus);

        Output memory output = Output({
            quoteVersion: quoteVersion,
            quoteBodyType: 1,
            tcbStatus: uint8(tcbStatus),
            fmspcBytes: bytes6(pckTcb.fmspcBytes),
            quoteBody: rawQuoteBody,
            advisoryIDs: tcbLevels[tcbLevelSelected].advisoryIDs
        });
        serialized = serializeOutput(output);
        success = true;
    }

    function _verifyTDXQuote(
        uint32 tcbEvalNumber,
        bytes memory rawQuoteHeader,
        bytes memory rawQuoteBody,
        AuthData memory authData
    ) private view returns (bool success, bytes memory serialized) {
        VerificationResult memory result =
            _verifyQuoteIntegrity(4, tcbEvalNumber, TDX_TEE, rawQuoteHeader, rawQuoteBody, authData);
        if (!result.success) {
            return (false, bytes(result.reason));
        }

        PCKCertTCB memory pckTcb = authData.certification.pckExtension;
        (TCBLevelsObj[] memory tcbLevels, TDXModule memory tdxModule, TDXModuleIdentity[] memory tdxModuleIdentities) =
            pccsRouter.getFmspcTcbV3(TcbId.TDX, bytes6(pckTcb.fmspcBytes), result.tcbEvalNumber);

        // Parse the TDX quote body
        TD10ReportBody memory reportBody;
        (success, reportBody) = TD10ReportParser.parse(rawQuoteBody);
        if (!success) {
            return (false, bytes(TD10F));
        }

        TCBStatus tcbStatus;
        uint256 tcbLevelSelected;
        (success,, tcbStatus, tcbLevelSelected) = getTDXTcbStatus(tcbLevels, pckTcb, reportBody.teeTcbSvn);
        if (!success || tcbStatus == TCBStatus.TCB_REVOKED) {
            return (false, bytes(TCBR));
        }

        TCBStatus tdxModuleStatus;
        bytes memory expectedMrSignerSeam;
        bytes8 expectedSeamAttributes;
        (success, tdxModuleStatus, expectedMrSignerSeam, expectedSeamAttributes) =
            checkTdxModuleTcbStatus(reportBody.teeTcbSvn, tdxModule, tdxModuleIdentities);
        if (!success || tdxModuleStatus == TCBStatus.TCB_REVOKED) {
            return (false, bytes(TCBR));
        }

        success = checkTdxModule(
            reportBody.mrsignerSeam, expectedMrSignerSeam, reportBody.seamAttributes, expectedSeamAttributes
        );
        if (!success) {
            return (false, bytes(TDMF));
        }

        tcbStatus = convergeTcbStatusWithTdxModuleStatus(tcbStatus, tdxModuleStatus);
        tcbStatus = convergeTcbStatusWithQeTcbStatus(result.qeTcbStatus, tcbStatus);

        Output memory output = Output({
            quoteVersion: quoteVersion,
            quoteBodyType: 2, // TD10 Report
            tcbStatus: uint8(tcbStatus),
            fmspcBytes: bytes6(pckTcb.fmspcBytes),
            quoteBody: rawQuoteBody,
            advisoryIDs: tcbLevels[tcbLevelSelected].advisoryIDs
        });
        serialized = serializeOutput(output);
    }

    /**
     * @dev set visibility to internal because this can be reused by V5 or above QuoteVerifiers
     *
     * [0:64] bytes: ecdsa256BitSignature
     * [64:128] bytes: ecdsaAttestationKey
     * [128:130] bytes: qeReportCertType
     * [130:134] bytes: qeReportCertSize (X)
     * NOTE: the calculations below assume qeReportCertType == 6
     * [134:518] bytes: qeReport
     * [518:582] bytes: qeReportSignature
     * [582:584] bytes: qeAuthDataSize (Y)
     * [584:584+Y] bytes: qeAuthData
     * [584+Y:586+Y] bytes: pckCertType
     * NOTE: the calculations below assume pckCertType == 5
     * [586+Y:590+Y] bytes: certSize (Z)
     * [590+Y:590+Y+Z] bytes: certData
     */
    function _parseAuthData(bytes calldata rawAuthData)
        private
        view
        returns (bool success, AuthData memory authData)
    {
        authData.ecdsa256BitSignature = rawAuthData[0:64];
        authData.ecdsaAttestationKey = rawAuthData[64:128];

        uint256 qeReportCertType = BELE.leBytesToBeUint(rawAuthData[128:130]);
        if (qeReportCertType != 6) {
            return (false, authData);
        }
        uint256 qeReportCertSize = BELE.leBytesToBeUint(rawAuthData[130:134]);
        authData.qeReportSignature = rawAuthData[518:582];

        uint16 qeAuthDataSize = uint16(BELE.leBytesToBeUint(rawAuthData[582:584]));
        uint256 offset = 584;
        authData.qeAuthData = rawAuthData[offset:offset + qeAuthDataSize];
        offset += qeAuthDataSize;

        uint16 certType = uint16(BELE.leBytesToBeUint(rawAuthData[offset:offset + 2]));
        if (certType != 5) {
            return (false, authData);
        }

        offset += 2;
        uint32 certDataSize = uint32(BELE.leBytesToBeUint(rawAuthData[offset:offset + 4]));
        offset += 4;
        bytes memory rawCertData = rawAuthData[offset:offset + certDataSize];
        offset += certDataSize;

        if (offset - 134 != qeReportCertSize) {
            return (false, authData);
        }

        authData.qeReport = rawAuthData[134:518];

        (success, authData.certification) =
            getPckCollateral(pccsRouter.pckHelperAddr(), certType, rawCertData);
        if (!success) {
            return (false, authData);
        }
    }
}
