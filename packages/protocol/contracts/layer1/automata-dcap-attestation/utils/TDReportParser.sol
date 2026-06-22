//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../types/Constants.sol";
import {BytesUtils} from "./BytesUtils.sol";
import {TD10ReportBody, TD15ReportBody} from "../types/TDXStruct.sol";

library TD10ReportParser {
    using BytesUtils for bytes;

    /**
     * @dev set visibility to internal because this can be reused by V5 or above QuoteVerifiers
     */
    function parse(bytes memory reportBytes) internal pure returns (bool success, TD10ReportBody memory report) {
        success = reportBytes.length == TD_REPORT10_LENGTH;
        if (success) {
            report.teeTcbSvn = bytes16(reportBytes.substring(0, 16));
            report.mrSeam = reportBytes.substring(16, 48);
            report.mrsignerSeam = reportBytes.substring(64, 48);
            report.seamAttributes = bytes8(reportBytes.substring(112, 8));
            report.tdAttributes = bytes8(reportBytes.substring(120, 8));
            report.xFAM = bytes8(reportBytes.substring(128, 8));
            report.mrTd = reportBytes.substring(136, 48);
            report.mrConfigId = reportBytes.substring(184, 48);
            report.mrOwner = reportBytes.substring(232, 48);
            report.mrOwnerConfig = reportBytes.substring(280, 48);
            report.rtMr0 = reportBytes.substring(328, 48);
            report.rtMr1 = reportBytes.substring(376, 48);
            report.rtMr2 = reportBytes.substring(424, 48);
            report.rtMr3 = reportBytes.substring(472, 48);
            report.reportData = reportBytes.substring(520, 64);
        }
    }
}

library TD15ReportParser {
    using BytesUtils for bytes;

    function parse(bytes memory reportBytes) internal pure returns (bool success, TD15ReportBody memory report) {
        success = reportBytes.length == TD_REPORT15_LENGTH;
        if (success) {
            report.teeTcbSvn = bytes16(reportBytes.substring(0, 16));
            report.mrSeam = reportBytes.substring(16, 48);
            report.mrsignerSeam = reportBytes.substring(64, 48);
            report.seamAttributes = bytes8(reportBytes.substring(112, 8));
            report.tdAttributes = bytes8(reportBytes.substring(120, 8));
            report.xFAM = bytes8(reportBytes.substring(128, 8));
            report.mrTd = reportBytes.substring(136, 48);
            report.mrConfigId = reportBytes.substring(184, 48);
            report.mrOwner = reportBytes.substring(232, 48);
            report.mrOwnerConfig = reportBytes.substring(280, 48);
            report.rtMr0 = reportBytes.substring(328, 48);
            report.rtMr1 = reportBytes.substring(376, 48);
            report.rtMr2 = reportBytes.substring(424, 48);
            report.rtMr3 = reportBytes.substring(472, 48);
            report.reportData = reportBytes.substring(520, 64);
            report.teeTcbSvn2 = bytes16(reportBytes.substring(584, 16));
            report.mrServiceTd = reportBytes.substring(600, 48);
        }
    }
}
