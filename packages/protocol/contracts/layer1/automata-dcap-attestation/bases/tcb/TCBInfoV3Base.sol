//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    TcbId,
    TDXModule,
    TDXModuleIdentity,
    TDXModuleTCBLevelsObj
} from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";
import {BELE} from "../../utils/BELE.sol";
import "./TCBInfoV2Base.sol";

abstract contract TCBInfoV3Base is TCBInfoV2Base {
    uint256 constant TCB_LEVEL_ERROR = type(uint256).max;

    /// @dev Modified from https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationLibrary/blob/7e5b2a13ca5472de8d97dd7d7024c2ea5af9a6ba/Src/AttestationLibrary/src/Verifiers/Checks/TcbLevelCheck.cpp#L129-L181
    function getTDXTcbStatus(TCBLevelsObj[] memory tcbLevels, PCKCertTCB memory pckTcb, bytes16 teeTcbSvn)
        internal
        pure
        returns (bool tdxTcbFound, TCBStatus sgxStatus, TCBStatus tdxStatus, uint256 tcbLevelSelected)
    {
        sgxStatus = TCBStatus.TCB_UNRECOGNIZED;
        tdxStatus = TCBStatus.TCB_UNRECOGNIZED;
        tcbLevelSelected = TCB_LEVEL_ERROR;
        
        bool pceSvnIsHigherOrGreater;
        bool cpuSvnsAreHigherOrGreater;
        bool sgxTcbFound = sgxStatus != TCBStatus.TCB_UNRECOGNIZED;
        for (uint256 i = 0; i < tcbLevels.length; i++) {
            TCBLevelsObj memory current = tcbLevels[i];
            if (!sgxTcbFound) {
                (pceSvnIsHigherOrGreater, cpuSvnsAreHigherOrGreater) = _checkSgxCpuSvns(pckTcb, current);
            }
            if (pceSvnIsHigherOrGreater && cpuSvnsAreHigherOrGreater) {
                sgxTcbFound = true;
                sgxStatus = current.status;
            }
            if (sgxTcbFound && sgxStatus != TCBStatus.TCB_REVOKED) {
                if (teeTcbSvn != bytes16(0)) {
                    if (_isTdxTcbHigherOrEqual(teeTcbSvn, current.tdxComponentCpuSvns)) {
                        tdxTcbFound = true;
                        tdxStatus = current.status;
                        tcbLevelSelected = i;
                    }
                } else {
                    break;
                }
            } else if (sgxStatus == TCBStatus.TCB_REVOKED) {
                return (false, TCBStatus.TCB_REVOKED, TCBStatus.TCB_REVOKED, TCB_LEVEL_ERROR);
            }
            if (tdxTcbFound) {
                return (true, sgxStatus, tdxStatus, tcbLevelSelected);
            }
        }
    }

    function _isTdxTcbHigherOrEqual(bytes16 teeTcbSvn, uint8[] memory tdxComponentCpuSvns)
        private
        pure
        returns (bool)
    {
        if (tdxComponentCpuSvns.length != CPUSVN_LENGTH) {
            return false;
        }

        for (uint256 i = 0; i < CPUSVN_LENGTH; i++) {
            if (uint8(teeTcbSvn[i]) < uint8(tdxComponentCpuSvns[i])) {
                return false;
            }
        }

        return true;
    }
}
