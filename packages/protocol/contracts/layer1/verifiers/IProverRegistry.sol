// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./IVerifier.sol";

interface IProverRegistry {
    struct ProverInstance {
        address addr;
        uint256 validUntil;
        uint256 teeType; // 1: IntelTDX
    }

    struct SignedPoe {
        TaikoData.Transition transition;
        uint256 id;
        address newInstance;
        bytes signature;
        uint256 teeType; // 1: IntelTDX
    }

    struct Proof {
        SignedPoe poe;
        IVerifier.Context ctx;
    }

    struct ReportData {
        address addr;
        uint256 teeType;
        uint256 referenceBlockNumber;
        bytes32 referenceBlockHash;
        bytes32 binHash;

        bytes ext;
    }

    error INVALID_BLOCK_NUMBER();
    error BLOCK_NUMBER_OUT_OF_DATE();
    error BLOCK_NUMBER_MISMATCH();
    error REPORT_USED();
    error INVALID_PROVER_INSTANCE();
    error PROVER_INVALID_PROOF();
    error PROVER_INVALID_INSTANCE_ID(uint256);
    error PROVER_INVALID_ADDR(address);
    error PROVER_TYPE_MISMATCH();
    error PROVER_ADDR_MISMATCH(address, address);
    error PROVER_OUT_OF_DATE(uint256);

    // attestation verifier
    error INVALID_REPORT();
    error INVALID_REPORT_DATA();
    error REPORT_DATA_MISMATCH(bytes32 want, bytes32 got);
    error INVALID_PRC10(bytes32 pcr10);

    event InstanceAdded(
        uint256 indexed id,
        address indexed instance,
        address replaced,
        uint256 validUntil
    );
    event VerifyProof(uint256 proofs);

    /// @notice register prover instance with quote
    function register(
        bytes calldata _report,
        ReportData calldata _data
    ) external;

    /// TODO: should we need to add teeType?
    /// @notice validate whether the prover with (instanceID, address)
    function checkProver(
        uint256 _instanceID,
        address _proverAddr
    ) external view returns (ProverInstance memory);

    /// TODO: each proof should coming from different teeType
    /// @notice verify multiple proofs in one call
    function verifyProofs(Proof[] calldata _proofs) external;
}