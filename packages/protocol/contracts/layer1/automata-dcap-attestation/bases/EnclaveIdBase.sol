//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    IdentityObj,
    EnclaveId,
    Tcb,
    EnclaveIdTcbStatus
} from "@automata-network/on-chain-pccs/helpers/EnclaveIdentityHelper.sol";

abstract contract EnclaveIdBase {
    /// @dev https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationLibrary/blob/16b7291a7a86e486fdfcf1dfb4be885c0cc00b4e/Src/AttestationLibrary/src/Verifiers/EnclaveReportVerifier.cpp#L47-L113
    function verifyQEReportWithIdentity(
        IdentityObj memory identity,
        bytes4 enclaveReportMiscselect,
        bytes16 enclaveReportAttributes,
        bytes32 enclaveReportMrsigner,
        uint16 enclaveReportIsvprodid,
        uint16 enclaveReportIsvSvn
    ) internal pure returns (bool, EnclaveIdTcbStatus status) {
        bool miscselectMatched = enclaveReportMiscselect & identity.miscselectMask == identity.miscselect;
        bool attributesMatched = enclaveReportAttributes & identity.attributesMask == identity.attributes;
        bool mrsignerMatched = enclaveReportMrsigner == identity.mrsigner;
        bool isvprodidMatched = enclaveReportIsvprodid == identity.isvprodid;

        bool tcbFound;
        for (uint256 i = 0; i < identity.tcb.length; i++) {
            if (identity.tcb[i].isvsvn <= enclaveReportIsvSvn) {
                tcbFound = true;
                status = identity.tcb[i].status;
                break;
            }
        }
        return (miscselectMatched && attributesMatched && mrsignerMatched && isvprodidMatched && tcbFound, status);
    }
}
