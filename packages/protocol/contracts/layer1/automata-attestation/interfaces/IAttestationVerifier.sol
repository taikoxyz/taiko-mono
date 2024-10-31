//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAttestationVerifier
interface IAttestationVerifier {
    struct ExtTpmInfo {
        bytes32 pcr10;
        bytes quote;
        bytes signature;
        bytes akDer;
    }

    error INVALID_REPORT();
    error INVALID_REPORT_DATA();
    error REPORT_DATA_MISMATCH(bytes32 want, bytes32 got);
    error INVALID_PRC10(bytes32 pcr10);

    function setImagePcr10(bytes32 _pcr10, bool _trusted) external;
    function verifyAttestation(bytes calldata _report, bytes32 _userData, bytes calldata ext) external;
}
