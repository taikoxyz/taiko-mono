//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TD10ReportParser, TD15ReportParser} from "../utils/TDReportParser.sol";
import "../types/Errors.sol";
import "../bases/TdxQuoteBase.sol";

contract V5QuoteVerifier is TdxQuoteBase {
    uint8 constant TCB_TD_RELAUNCH_ADVISED = 8;
    uint8 constant TCB_TD_RELAUNCH_ADVISED_CONFIGURATION_NEEDED = 9;

    constructor(address _ecdsaVerifier, address _router) QuoteVerifierBase(_router, 5) P256Verifier(_ecdsaVerifier) {}

    function verifyQuote(Header calldata header, bytes calldata rawQuote, uint32 tcbEvalNumber)
        external
        view
        override
        returns (bool success, bytes memory serializedOutput)
    {
        string memory reason;
        uint16 quoteBodyType;
        uint32 quoteBodySize;
        AuthData memory authData;

        (success, reason, quoteBodyType, quoteBodySize, authData) = _parseV5Quote(header, rawQuote);
        if (!success) {
            return (false, bytes(reason));
        }

        bytes memory rawHeader = rawQuote[0:HEADER_LENGTH];
        bytes memory rawBody = rawQuote[HEADER_LENGTH:HEADER_LENGTH + 2 + 4 + quoteBodySize];

        VerificationResult memory result =
            _verifyQuoteIntegrity(4, tcbEvalNumber, header.teeType, rawHeader, rawBody, authData);
        if (!result.success) {
            return (false, bytes(result.reason));
        }

        PCKCertTCB memory pckTcb = authData.certification.pckExtension;
        (TCBLevelsObj[] memory tcbLevels, TDXModule memory tdxModule, TDXModuleIdentity[] memory tdxModuleIdentities) =
        pccsRouter.getFmspcTcbV3(
            header.teeType == SGX_TEE ? TcbId.SGX : TcbId.TDX, bytes6(pckTcb.fmspcBytes), result.tcbEvalNumber
        );

        uint8 tcbStatus = uint8(TCBStatus.TCB_UNRECOGNIZED);
        uint256 tcbLevelSelected = TCB_LEVEL_ERROR;
        uint256 bodyOffset = HEADER_LENGTH + 2 + 4;

        if (header.teeType == SGX_TEE) {
            bool statusFound;
            TCBStatus sgxStatus;
            for (uint256 i = 0; i < tcbLevels.length; i++) {
                (statusFound, sgxStatus) = getSGXTcbStatus(pckTcb, tcbLevels[i]);
                if (statusFound) {
                    tcbLevelSelected = i;
                    break;
                }
            }
            if (sgxStatus == TCBStatus.TCB_REVOKED) {
                return (false, bytes(TCBR));
            }
            sgxStatus = convergeTcbStatusWithQeTcbStatus(result.qeTcbStatus, sgxStatus);
            tcbStatus = uint8(sgxStatus);
        } else {
            bytes16 teeTcbSvn;
            bytes memory mrSignerSeam;
            bytes8 seamAttributes;
            bytes16 teeTcbSvn2;

            (success, reason, teeTcbSvn, mrSignerSeam, seamAttributes, teeTcbSvn2) =
                _parseTdReport(rawQuote[bodyOffset:bodyOffset + quoteBodySize]);
            if (!success) {
                return (false, bytes(reason));
            }

            TCBStatus sgxStatus = TCBStatus.TCB_UNRECOGNIZED;
            TCBStatus tdxStatus = TCBStatus.TCB_UNRECOGNIZED;
            (success, sgxStatus, tdxStatus, tcbLevelSelected) = getTDXTcbStatus(tcbLevels, pckTcb, teeTcbSvn);
            if (!success || tdxStatus == TCBStatus.TCB_REVOKED) {
                return (false, bytes(TCBR));
            }

            TCBStatus tdxModuleStatus;
            bytes memory expectedMrSignerSeam;
            bytes8 expectedSeamAttributes;
            (success, tdxModuleStatus, expectedMrSignerSeam, expectedSeamAttributes) =
                checkTdxModuleTcbStatus(teeTcbSvn, tdxModule, tdxModuleIdentities);
            if (!success || tdxModuleStatus == TCBStatus.TCB_REVOKED) {
                return (false, bytes(TCBR));
            }

            success = checkTdxModule(mrSignerSeam, expectedMrSignerSeam, seamAttributes, expectedSeamAttributes);
            if (!success) {
                return (false, bytes(TDMF));
            }

            tdxStatus = convergeTcbStatusWithTdxModuleStatus(tdxStatus, tdxModuleStatus);

            if (quoteBodySize == TD_REPORT15_LENGTH) {
                // Relaunch check (TD 1.5 only)
                bool relaunchAdvised;
                bool configurationNeeded;
                (success, reason, relaunchAdvised, configurationNeeded) =
                    _checkForRelaunch(teeTcbSvn2, result.qeTcbStatus, sgxStatus, tdxStatus, tdxModuleStatus, tcbLevels, tdxModuleIdentities);
                if (!success) {
                    return (false, bytes(reason));
                }
                if (relaunchAdvised) {
                    tcbStatus =
                        configurationNeeded ? TCB_TD_RELAUNCH_ADVISED_CONFIGURATION_NEEDED : TCB_TD_RELAUNCH_ADVISED;
                }
            }

            tcbStatus = uint8(convergeTcbStatusWithQeTcbStatus(result.qeTcbStatus, tdxStatus));
        }

        Output memory output = Output({
            quoteVersion: quoteVersion,
            quoteBodyType: quoteBodyType,
            tcbStatus: tcbStatus,
            fmspcBytes: bytes6(pckTcb.fmspcBytes),
            quoteBody: rawQuote[bodyOffset:bodyOffset + quoteBodySize],
            advisoryIDs: tcbLevels[tcbLevelSelected].advisoryIDs
        });

        serializedOutput = serializeOutput(output);
        success = true;
    }

    function _parseV5Quote(Header calldata header, bytes calldata quote)
        private
        view
        returns (
            bool success,
            string memory reason,
            uint16 quoteBodyType,
            uint32 quoteBodySize,
            AuthData memory authData
        )
    {
        bytes4 teeType = header.teeType;
        (success, reason) = validateHeader(header, quote.length, teeType == SGX_TEE || teeType == TDX_TEE);
        if (!success) {
            return (success, reason, 0, 0, authData);
        }

        uint256 offset = HEADER_LENGTH;

        quoteBodyType = uint16(BELE.leBytesToBeUint(quote[offset:offset + 2]));
        offset += 2;

        uint32 expectedBodySize;
        if (teeType == SGX_TEE) {
            if (quoteBodyType != 1) {
                return (false, QBF, 0, 0, authData);
            }
            expectedBodySize = ENCLAVE_REPORT_LENGTH;
        } else {
            if (quoteBodyType == 2) {
                expectedBodySize = TD_REPORT10_LENGTH;
            } else if (quoteBodyType == 3) {
                expectedBodySize = TD_REPORT15_LENGTH;
            } else {
                return (false, QBF, 0, 0, authData);
            }
        }

        quoteBodySize = uint32(BELE.leBytesToBeUint(quote[offset:offset + 4]));
        if (quoteBodySize != expectedBodySize) {
            return (false, QBS, 0, 0, authData);
        }
        offset += 4 + quoteBodySize;

        uint256 localAuthDataSize = BELE.leBytesToBeUint(quote[offset:offset + 4]);
        offset += 4;
        if (quote.length - offset < localAuthDataSize) {
            return (false, ADS, 0, 0, authData);
        }

        (success, authData) = _parseAuthData(quote[offset:offset + localAuthDataSize]);
        if (!success) {
            return (false, ADF, 0, 0, authData);
        }
    }

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

    function _parseTdReport(bytes calldata rawTdReport)
        private
        pure
        returns (
            bool success,
            string memory reason,
            bytes16 teeTcbSvn,
            bytes memory mrSignerSeam,
            bytes8 seamAttributes,
            bytes16 teeTcbSvn2
        )
    {
        if (rawTdReport.length == TD_REPORT10_LENGTH) {
            TD10ReportBody memory td10ReportBody;
            (success, td10ReportBody) = TD10ReportParser.parse(rawTdReport);
            if (!success) {
                return (false, TD10F, teeTcbSvn, mrSignerSeam, seamAttributes, teeTcbSvn2);
            }
            teeTcbSvn = td10ReportBody.teeTcbSvn;
            mrSignerSeam = td10ReportBody.mrsignerSeam;
            seamAttributes = td10ReportBody.seamAttributes;
        } else {
            TD15ReportBody memory td15ReportBody;
            (success, td15ReportBody) = TD15ReportParser.parse(rawTdReport);
            if (!success) {
                return (false, TD15F, teeTcbSvn, mrSignerSeam, seamAttributes, teeTcbSvn2);
            }
            teeTcbSvn = td15ReportBody.teeTcbSvn;
            teeTcbSvn2 = td15ReportBody.teeTcbSvn2;
            mrSignerSeam = td15ReportBody.mrsignerSeam;
            seamAttributes = td15ReportBody.seamAttributes;
        }
    }

    /// https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationLibrary/blob/stable/Src/AttestationLibrary/src/Verifiers/Checks/TDRelaunchCheck.cpp
    function _checkForRelaunch(
        bytes16 teeTcbSvn2,
        EnclaveIdTcbStatus qeTcbStatus,
        TCBStatus sgxStatus,
        TCBStatus tdxStatus,
        TCBStatus tdxModuleStatus,
        TCBLevelsObj[] memory tcbLevels,
        TDXModuleIdentity[] memory tdxModuleIdentities
    ) private pure returns (bool success, string memory reason, bool relaunchAdvised, bool configurationNeeded) {
        success = true;
        
        if (qeTcbStatus != EnclaveIdTcbStatus.SGX_ENCLAVE_REPORT_ISVSVN_OUT_OF_DATE) {
            if (sgxStatus != TCBStatus.TCB_OUT_OF_DATE && sgxStatus != TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED) {
                if (
                    tdxStatus == TCBStatus.TCB_OUT_OF_DATE
                        || tdxStatus == TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED
                ) {
                    if (tdxModuleStatus == TCBStatus.TCB_OUT_OF_DATE) {
                        configurationNeeded = _tcbConfigurationNeeded(sgxStatus) || _tcbConfigurationNeeded(tdxStatus);
                        TCBLevelsObj memory latestTcbLevel = tcbLevels[0];

                        if (teeTcbSvn2[1] == 0) {
                            if (
                                uint8(teeTcbSvn2[0]) >= latestTcbLevel.tdxComponentCpuSvns[0]
                                    && uint8(teeTcbSvn2[2]) >= latestTcbLevel.tdxComponentCpuSvns[2]
                            ) {
                                relaunchAdvised = true;
                            }
                        } else {
                            TDXModuleIdentity memory matchingModuleIdentity;
                            (success, matchingModuleIdentity) =
                                findTdxModuleIdentity(tdxModuleIdentities, uint8(teeTcbSvn2[1]));
                            if (!success) {
                                return
                                    (false, TDRF, false, false);
                            }

                            TDXModuleTCBLevelsObj memory latestTdxModuleTcbLevel = matchingModuleIdentity.tcbLevels[0];
                            if (
                                uint8(teeTcbSvn2[0]) >= latestTdxModuleTcbLevel.isvsvn
                                    && uint8(teeTcbSvn2[2]) >= latestTcbLevel.tdxComponentCpuSvns[2]
                            ) {
                                relaunchAdvised = true;
                            }
                        }
                    }
                }
            }
        }
    }

    function _tcbConfigurationNeeded(TCBStatus tcbStatus) private pure returns (bool) {
        return tcbStatus == TCBStatus.TCB_CONFIGURATION_NEEDED
            || tcbStatus == TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED
            || tcbStatus == TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED;
    }
}
