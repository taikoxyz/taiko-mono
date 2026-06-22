//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice V4 Intel TDX Quote uses this struct as the quote body
 * @dev Section A.3.2 of Intel V4 TDX DCAP API Library Documentation
 * @dev https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationLibrary/blob/7e5b2a13ca5472de8d97dd7d7024c2ea5af9a6ba/Src/AttestationLibrary/src/QuoteVerification/QuoteStructures.h#L82-L103
 */
struct TD10ReportBody {
    bytes16 teeTcbSvn;
    bytes mrSeam; // 48 bytes
    bytes mrsignerSeam; // 48 bytes
    bytes8 seamAttributes;
    bytes8 tdAttributes;
    bytes8 xFAM;
    bytes mrTd; // 48 bytes
    bytes mrConfigId; // 48 bytes
    bytes mrOwner; // 48 bytes
    bytes mrOwnerConfig; // 48 bytes
    bytes rtMr0; // 48 bytes
    bytes rtMr1; // 48 bytes
    bytes rtMr2; // 48 bytes
    bytes rtMr3; // 48 bytes
    bytes reportData; // 64 bytes
}

struct TD15ReportBody {
    bytes16 teeTcbSvn;
    bytes mrSeam; // 48 bytes
    bytes mrsignerSeam; // 48 bytes
    bytes8 seamAttributes;
    bytes8 tdAttributes;
    bytes8 xFAM;
    bytes mrTd; // 48 bytes
    bytes mrConfigId; // 48 bytes
    bytes mrOwner; // 48 bytes
    bytes mrOwnerConfig; // 48 bytes
    bytes rtMr0; // 48 bytes
    bytes rtMr1; // 48 nytes
    bytes rtMr2; // 48 bytes
    bytes rtMr3; // 48 bytes
    bytes reportData; // 64 bytes
    bytes16 teeTcbSvn2;
    bytes mrServiceTd; // 48 bytes
}