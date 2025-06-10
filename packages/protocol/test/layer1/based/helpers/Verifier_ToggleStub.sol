// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/surge/verifiers/ISurgeVerifier.sol";
import "src/layer1/surge/verifiers/LibProofType.sol";

// Surge: change the contract interface to ISurgeVerifier
contract Verifier_ToggleStub is ISurgeVerifier {
    using LibProofType for LibProofType.ProofType;

    LibProofType.ProofType public proofType;
    LibProofType.ProofType public proofTypeToUpgrade;

    constructor() {
        proofType = LibProofType.sgxReth().combine(LibProofType.sp1Reth());
        proofTypeToUpgrade = LibProofType.empty();
    }

    function setProofType(LibProofType.ProofType _proofType) external {
        proofType = _proofType;
    }

    function verifyProof(
        IVerifier.Context[] calldata,
        bytes calldata
    )
        external
        view
        returns (LibProofType.ProofType)
    {
        return proofType;
    }

    function markUpgradeable(LibProofType.ProofType _proofType) external {
        proofTypeToUpgrade = _proofType;
    }

    function upgradeVerifier(LibProofType.ProofType _proofType, address _newVerifier) external { }
}
