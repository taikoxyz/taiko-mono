//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    TCBStatus,
    TcbId,
    TCBLevelsObj,
    TDXModule,
    TDXModuleIdentity
} from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";
import {TD10ReportBody, TD15ReportBody} from "../utils/TDReportParser.sol";
import {PCKCertTCB} from "../types/CommonStruct.sol";

import "./QuoteVerifierBase.sol";
import "./tcb/TCBInfoV3Base.sol";

abstract contract TdxQuoteBase is QuoteVerifierBase, TCBInfoV3Base {
    using LibString for string;

    function checkTdxModule(
        bytes memory mrsignerSeam,
        bytes memory expectedMrSignerSeam,
        bytes8 seamAttributes,
        bytes8 expectedSeamAttributes
    ) internal pure returns (bool) {
        return keccak256(mrsignerSeam) == keccak256(expectedMrSignerSeam) && seamAttributes == expectedSeamAttributes;
    }

    /// @dev https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationLibrary/blob/7e5b2a13ca5472de8d97dd7d7024c2ea5af9a6ba/Src/AttestationLibrary/src/Verifiers/Checks/TdxModuleCheck.cpp#L99-L135
    function convergeTcbStatusWithTdxModuleStatus(TCBStatus tdxTcbStatus, TCBStatus tdxModuleTcbStatus)
        internal
        pure
        returns (TCBStatus convergedStatus)
    {
        convergedStatus = tdxTcbStatus; // Default to TDX TCB status
        if (tdxModuleTcbStatus == TCBStatus.TCB_OUT_OF_DATE) {
            if (tdxTcbStatus == TCBStatus.OK || tdxTcbStatus == TCBStatus.TCB_SW_HARDENING_NEEDED) {
                convergedStatus = TCBStatus.TCB_OUT_OF_DATE;
            }
            if (
                tdxTcbStatus == TCBStatus.TCB_CONFIGURATION_NEEDED
                    || tdxTcbStatus == TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED
            ) {
                convergedStatus = TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED;
            }
        }
    }

     /// @dev https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationLibrary/blob/7e5b2a13ca5472de8d97dd7d7024c2ea5af9a6ba/Src/AttestationLibrary/src/Verifiers/Checks/TdxModuleCheck.cpp#L62-L97
    function checkTdxModuleTcbStatus(bytes16 teeTcbSvn, TDXModule memory tdxModule, TDXModuleIdentity[] memory tdxModuleIdentities)
        internal
        pure
        returns (bool, TCBStatus, bytes memory, bytes8)
    {
        uint8 tdxModuleIsvSvn = uint8(teeTcbSvn[0]);
        uint8 tdxModuleVersion = uint8(teeTcbSvn[1]);
        bytes memory expectedMrSignerSeam = tdxModule.mrsigner;
        bytes8 expectedSeamAttributes = tdxModule.attributes;

        if (tdxModuleVersion == 0) {
            return (true, TCBStatus.OK, expectedMrSignerSeam, expectedSeamAttributes);
        }

        (bool tdxModuleIdentityFound, TDXModuleIdentity memory tdxModuleIdentity) =
            findTdxModuleIdentity(tdxModuleIdentities, tdxModuleVersion);

        if (tdxModuleIdentityFound) {
            TDXModuleTCBLevelsObj[] memory tdxModuleTcbLevels = tdxModuleIdentity.tcbLevels;
            for (uint256 i = 0; i < tdxModuleTcbLevels.length; i++) {
                if (tdxModuleIsvSvn >= uint8(tdxModuleTcbLevels[i].isvsvn)) {
                    expectedMrSignerSeam = tdxModuleIdentity.mrsigner;
                    expectedSeamAttributes = tdxModuleIdentity.attributes;
                    return (true, tdxModuleTcbLevels[i].status, expectedMrSignerSeam, expectedSeamAttributes);
                }
            }
        }

        return (false, TCBStatus.TCB_UNRECOGNIZED, expectedMrSignerSeam, expectedSeamAttributes);
    }

    function findTdxModuleIdentity(TDXModuleIdentity[] memory tdxModuleIdentities, uint8 tdxModuleVersion)
        internal
        pure
        returns (bool found, TDXModuleIdentity memory tdxModuleIdentity)
    {
        string memory tdxModuleIdentityId = string(
            abi.encodePacked(bytes("TDX_"), bytes(LibString.toHexStringNoPrefix(abi.encodePacked(tdxModuleVersion))))
        );

        for (uint256 i = 0; i < tdxModuleIdentities.length; i++) {
            if (tdxModuleIdentityId.eq(tdxModuleIdentities[i].id)) {
                return (true, tdxModuleIdentities[i]);
            }
        }

        return (false, tdxModuleIdentity);
    }
}
