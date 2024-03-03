//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title EnclaveIdStruct
/// @custom:security-contact security@taiko.xyz
library EnclaveIdStruct {
    struct EnclaveId {
        bytes4 miscselect;
        bytes4 miscselectMask;
        uint16 isvprodid;
        bytes16 attributes;
        bytes16 attributesMask;
        bytes32 mrsigner;
        TcbLevel[] tcbLevels;
    }

    struct TcbLevel {
        TcbObj tcb;
        EnclaveIdStatus tcbStatus;
    }

    struct TcbObj {
        uint16 isvsvn;
    }

    enum EnclaveIdStatus {
        OK,
        SGX_ENCLAVE_REPORT_ISVSVN_REVOKED
    }
}
