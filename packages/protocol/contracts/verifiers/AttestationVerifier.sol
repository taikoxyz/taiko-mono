// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { IAttestation } from "./IAttestation.sol";

contract AttestationVerifier {
    IAttestation public attestationVerifier;

    constructor(address _attestationVerifierAddr) {
        attestationVerifier = IAttestation(_attestationVerifierAddr);
    }

    error INVALID_REPORT();
    error INVALID_REPORT_DATA();
    error REPORT_DATA_MISMATCH();

    function verifyAttestation(bytes calldata _report, bytes32 _userData) public {
        if (address(attestationVerifier) == address(0)) return;

        (bool succ, bytes memory output) = attestationVerifier.verifyAndAttestOnChain(_report);
        if (!succ) revert INVALID_REPORT();

        if (output.length < 32) revert INVALID_REPORT_DATA();

        bytes32 quoteBodyLast32;
        assembly {
            quoteBodyLast32 := mload(add(add(output, 0x20), sub(mload(output), 32)))
        }

        if (quoteBodyLast32 != _userData) revert REPORT_DATA_MISMATCH();
    }
}
