// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../shared/common/EssentialContract.sol";
import "../automata-attestation/interfaces/IAttestationVerifier.sol";
import "../../shared/common/LibStrings.sol";
import "../based/ITaikoL1.sol";
import "../based/TaikoData.sol";
import "./IProverRegistry.sol";
import "./IVerifier.sol";
import "./LibPublicInput.sol";

contract ProverRegistryVerifier is IVerifier, IProverRegistry, EssentialContract {
    IAttestationVerifier public verifier; // slot 1
    uint256 public attestValiditySeconds; // slot 2
    uint256 public maxBlockNumberDiff; // slot 3
    uint256 public nextInstanceId = 0; // slot 4

    mapping(bytes32 reportHash => bool used) public attestedReports; // slot 5
    mapping(uint256 proverInstanceID => ProverInstance) public attestedProvers; // slot 6

    uint256[44] private __gap;

    function init(
        address _owner,
        address _rollupAddressManager,
        address _verifierAddr,
        uint256 _attestValiditySeconds,
        uint256 _maxBlockNumberDiff
    ) 
        external
        initializer
    {
        __Essential_init(_owner, _rollupAddressManager);

        verifier = IAttestationVerifier(_verifierAddr);
        attestValiditySeconds = _attestValiditySeconds;
        maxBlockNumberDiff = _maxBlockNumberDiff;
    }

    function reinitialize(
        uint8 i,
        address _verifierAddr,
        uint256 _attestValiditySeconds,
        uint256 _maxBlockNumberDiff
    )
        external
        onlyOwner
        reinitializer(i)
    {
        verifier = IAttestationVerifier(_verifierAddr);
        attestValiditySeconds = _attestValiditySeconds;
        maxBlockNumberDiff = _maxBlockNumberDiff;
    }

    /// @notice register prover instance with quote
    function register(
        bytes calldata _report,
        ReportData calldata _data
    )
        external
    {
        _checkBlockNumber(_data.referenceBlockNumber, _data.referenceBlockHash);
        bytes32 dataHash = keccak256(abi.encode(_data));

        verifier.verifyAttestation(_report, dataHash, _data.ext);

        bytes32 reportHash = keccak256(_report);
        if (attestedReports[reportHash]) revert REPORT_USED();
        attestedReports[reportHash] = true;

        uint256 instanceID = nextInstanceId + 1;
        nextInstanceId += 1;

        uint256 validUnitl = block.timestamp + attestValiditySeconds;
        attestedProvers[instanceID] = ProverInstance(
            _data.addr,
            validUnitl,
            _data.teeType
        );

        emit InstanceAdded(instanceID, _data.addr, address(0), validUnitl);
    }

    function verifyProof(
        IVerifier.Context calldata _ctx,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
        onlyFromNamedEither(LibStrings.B_TAIKO, LibStrings.B_TIER_TDX)
    {
        // Do not run proof verification to contest an existing proof
        if (_ctx.isContesting) return;

        // Size is: 89 bytes
        // 4 bytes + 20 bytes + 65 bytes (signature) = 89
        if (_proof.data.length != 89) revert PROVER_INVALID_PROOF();

        uint32 id = uint32(bytes4(_proof.data[:4]));
        address newInstance = address(bytes20(_proof.data[4:24]));

        address oldInstance = ECDSA.recover(
            LibPublicInput.hashPublicInputs(
                _tran, address(this), newInstance, _ctx.prover, _ctx.metaHash, uniFiChainId()
            ),
            _proof.data[24:]
        );

        ProverInstance memory prover = checkProver(id, oldInstance);
        if (_proof.tier != prover.teeType) revert PROVER_TYPE_MISMATCH();
        if (oldInstance != newInstance) {
            attestedProvers[id].addr = newInstance;
            emit InstanceAdded(id, oldInstance, newInstance, prover.validUntil);
        }
    }

    function verifyBatchProof(
        ContextV2[] calldata _ctxs,
        TaikoData.TierProof calldata _proof
    )
        external
        pure
        notImplemented
    { }

    /// TODO: each proof should coming from different teeType
    /// @notice verify multiple proofs in one call
    function verifyProofs(Proof[] calldata _proofs)
        external
        onlyFromNamedEither(LibStrings.B_TAIKO, LibStrings.B_TIER_TDX)
    {
        require(_proofs.length >= 1, "missing proofs");
        for (uint i = 0; i < _proofs.length; i++) {
            IProverRegistry.SignedPoe calldata poe = _proofs[i].poe;
            address oldInstance = ECDSA.recover(
                LibPublicInput.hashPublicInputs(
                    poe.transition, address(this), poe.newInstance, _proofs[i].ctx.prover,_proofs[i].ctx.metaHash, uniFiChainId()
                ),
                poe.signature
            );

            ProverInstance memory prover = checkProver(poe.id, oldInstance);
            if (poe.teeType != prover.teeType) revert PROVER_TYPE_MISMATCH();
            if (oldInstance != poe.newInstance) {
                attestedProvers[poe.id].addr = poe.newInstance;
                emit InstanceAdded(poe.id, oldInstance, poe.newInstance, prover.validUntil);
            }
        }

        emit VerifyProof(_proofs.length);
    }

    function checkProver(
        uint256 _instanceID,
        address _proverAddr
    ) public view returns (ProverInstance memory) {
        ProverInstance memory prover;
        if (_instanceID == 0) revert PROVER_INVALID_INSTANCE_ID(_instanceID);
        if (_proverAddr == address(0)) revert PROVER_INVALID_ADDR(_proverAddr);
        prover = attestedProvers[_instanceID];
        if (prover.addr != _proverAddr) revert PROVER_ADDR_MISMATCH(prover.addr, _proverAddr);
        if (prover.validUntil < block.timestamp) revert PROVER_OUT_OF_DATE(prover.validUntil);
        return prover;
    }

    function uniFiChainId() public view virtual returns (uint64) {
        return ITaikoL1(resolve(LibStrings.B_TAIKO, false)).getConfig().chainId;
    }

    // Due to the inherent unpredictability of blockHash, it mitigates the risk of mass-generation 
    //   of attestation reports in a short time frame, preventing their delayed and gradual exploitation.
    // This function will make sure the attestation report generated in recent ${maxBlockNumberDiff} blocks
    function _checkBlockNumber(
        uint256 blockNumber,
        bytes32 blockHash
    ) private view {
        if (blockNumber >= block.number) revert INVALID_BLOCK_NUMBER();
        if (block.number - blockNumber >= maxBlockNumberDiff)
            revert BLOCK_NUMBER_OUT_OF_DATE();
        if (blockhash(blockNumber) != blockHash) revert BLOCK_NUMBER_MISMATCH();
    }
}