//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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
        OK, // placeholder for value 0
        SGX_ENCLAVE_REPORT_ISVSVN_REVOKED
    }
}
