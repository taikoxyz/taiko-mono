//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TCBLevelsObj, TCBStatus} from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";
import {EnclaveIdTcbStatus} from "@automata-network/on-chain-pccs/helpers/EnclaveIdentityHelper.sol";
import {LibString} from "solady/utils/LibString.sol";
import {PCKCertTCB} from "../../types/CommonStruct.sol";

abstract contract TCBInfoV2Base {
    using LibString for string;

    // https://github.com/intel/SGXDataCenterAttestationPrimitives/blob/e7604e02331b3377f3766ed3653250e03af72d45/QuoteVerification/QVL/Src/AttestationLibrary/src/CertVerification/X509Constants.h#L64
    uint256 internal constant CPUSVN_LENGTH = 16;

    function getSGXTcbStatus(PCKCertTCB memory pckTcb, TCBLevelsObj memory current)
        internal
        pure
        returns (bool, TCBStatus status)
    {
        bool pceSvnIsHigherOrGreater;
        bool cpuSvnsAreHigherOrGreater;
        (pceSvnIsHigherOrGreater, cpuSvnsAreHigherOrGreater) = _checkSgxCpuSvns(pckTcb, current);
        status = current.status;
        bool statusFound = pceSvnIsHigherOrGreater && cpuSvnsAreHigherOrGreater;
        return (statusFound, statusFound ? status : TCBStatus.TCB_UNRECOGNIZED);
    }

    function _checkSgxCpuSvns(PCKCertTCB memory pckTcb, TCBLevelsObj memory tcbLevel)
        internal
        pure
        returns (bool, bool)
    {
        bool pceSvnIsHigherOrGreater = pckTcb.pcesvn >= tcbLevel.pcesvn;
        bool cpuSvnsAreHigherOrGreater = _isCpuSvnHigherOrGreater(pckTcb.cpusvns, tcbLevel.sgxComponentCpuSvns);
        return (pceSvnIsHigherOrGreater, cpuSvnsAreHigherOrGreater);
    }

    function _isCpuSvnHigherOrGreater(uint8[] memory pckCpuSvns, uint8[] memory tcbCpuSvns)
        internal
        pure
        returns (bool)
    {
        if (pckCpuSvns.length != CPUSVN_LENGTH || tcbCpuSvns.length != CPUSVN_LENGTH) {
            return false;
        }
        for (uint256 i = 0; i < CPUSVN_LENGTH; i++) {
            if (uint256(pckCpuSvns[i]) < tcbCpuSvns[i]) {
                return false;
            }
        }
        return true;
    }
}
