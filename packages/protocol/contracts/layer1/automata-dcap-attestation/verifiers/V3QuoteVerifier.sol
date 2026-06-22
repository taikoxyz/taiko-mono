//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TcbId } from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";
import "../bases/QuoteVerifierBase.sol";
import "../bases/tcb/TCBInfoV2Base.sol";
import "../types/Errors.sol";

/**
 * @title Automata DCAP QuoteV3 Verifier
 */
contract V3QuoteVerifier is QuoteVerifierBase, TCBInfoV2Base {
    constructor(address _ecdsaVerifier, address _router) QuoteVerifierBase(_router, 3) P256Verifier(_ecdsaVerifier) {}

    function verifyQuote(Header calldata header, bytes calldata rawQuote, uint32 tcbEvalNumber)
        external
        view
        override
        returns (bool success, bytes memory output)
    {
        string memory reason;
        AuthData memory authData;
        (success, reason, authData) = _parseV3Quote(header, rawQuote);
        if (!success) {
            return (false, bytes(reason));
        }

        bytes memory rawHeader = rawQuote[0:HEADER_LENGTH];
        bytes memory rawBody = rawQuote[HEADER_LENGTH:HEADER_LENGTH + ENCLAVE_REPORT_LENGTH];

        VerificationResult memory result =
            _verifyQuoteIntegrity(4, tcbEvalNumber, SGX_TEE, rawHeader, rawBody, authData);
        if (!result.success) {
            return (false, bytes(result.reason));
        }

        PCKCertTCB memory pckTcb = authData.certification.pckExtension;
        (TCBLevelsObj[] memory tcbLevels,,) = pccsRouter.getFmspcTcbV3(
            TcbId.SGX,
            bytes6(pckTcb.fmspcBytes), 
            result.tcbEvalNumber
        );
        TCBStatus tcbStatus;
        bool statusFound;
        for (uint256 i = 0; i < tcbLevels.length; i++) {
            (statusFound, tcbStatus) = getSGXTcbStatus(pckTcb, tcbLevels[i]);
            if (statusFound) {
                break;
            }
        }
        if (!statusFound || tcbStatus == TCBStatus.TCB_REVOKED) {
            return (statusFound, bytes(TCBR));
        }

        tcbStatus = convergeTcbStatusWithQeTcbStatus(result.qeTcbStatus, tcbStatus);

        Output memory out = Output({
            quoteVersion: quoteVersion,
            quoteBodyType: 1,
            tcbStatus: uint8(tcbStatus),
            fmspcBytes: bytes6(pckTcb.fmspcBytes),
            quoteBody: rawBody,
            advisoryIDs: new string[](0)
        });
        output = serializeOutput(out);
        success = true;
    }

    function _parseV3Quote(Header calldata header, bytes calldata quote)
        private
        view
        returns (bool success, string memory reason, AuthData memory authData)
    {
        (success, reason) = validateHeader(header, quote.length, header.teeType == SGX_TEE);
        if (!success) {
            return (success, reason, authData);
        }

        // now that we are able to confirm that the provided quote is a valid V3 SGX quote
        // based on information found in the header
        // we continue parsing the remainder of the quote

        uint256 offset = HEADER_LENGTH + ENCLAVE_REPORT_LENGTH;

        // check authData length
        uint256 localAuthDataSize = BELE.leBytesToBeUint(quote[offset:offset + 4]);
        offset += 4;
        // we don't strictly require the auth data to be equal to the provided length
        // but this ignores any trailing bytes after the indicated length allocated for authData
        if (quote.length - offset < localAuthDataSize) {
            return (false, ADS, authData);
        }

        // at this point, we have verified the length of the entire quote to be correct
        // parse authData
        (success, authData) = _parseAuthData(quote[offset:offset + localAuthDataSize]);
        if (!success) {
            return (false, ADF, authData);
        }

        success = true;
    }

    /**
     * [0:64] bytes: ecdsa256BitSignature
     * [64:128] bytes: ecdsaAttestationKey
     * [128:512] bytes: qeReport
     * [512:576] bytes: qeReportSignature
     * [576:578] bytes: qeAuthDataSize (Y)
     * [578:578+Y] bytes: qeAuthData
     * [578+Y:580+Y] bytes: pckCertType
     * NOTE: the calculations below assume pckCertType == 5
     * [580+Y:584+Y] bytes: certSize (Z)
     * [584+Y:584+Y+Z] bytes: certData
     */
    function _parseAuthData(bytes calldata rawAuthData)
        private
        view
        returns (bool success, AuthData memory authData)
    {
        authData.ecdsa256BitSignature = rawAuthData[0:64];
        authData.ecdsaAttestationKey = rawAuthData[64:128];
        authData.qeReport = rawAuthData[128:512];
        authData.qeReportSignature = rawAuthData[512:576];
        uint16 qeAuthDataSize = uint16(BELE.leBytesToBeUint(rawAuthData[576:578]));
        uint256 offset = 578;
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

        // parsing complete, now we need to decode some raw data

        (success, authData.certification) = getPckCollateral(pccsRouter.pckHelperAddr(), certType, rawCertData);
        if (!success) {
            return (false, authData);
        }
    }
}
