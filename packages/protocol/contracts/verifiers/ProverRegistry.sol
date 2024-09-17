// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../automata-attestation/lib/QuoteV3Auth/V3Struct.sol";
import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../L1/ITaikoL1.sol";
import "./libs/LibPublicInput.sol";
import "./AttestationVerifier.sol";
import "./IVerifier.sol";

contract ProverRegistry is EssentialContract, IVerifier {
    struct ProverInstance {
        address addr;
        uint256 validUntil;
        uint256 teeType; // 1: IntelTDX
    }

    struct ReportData {
        address addr;
        uint256 teeType;
        uint256 referenceBlockNumber;
        bytes32 referenceBlockHash;
        bytes32 binHash;
    }

    error INVALID_BLOCK_NUMBER();
    error BLOCK_NUMBER_OUT_OF_DATE();
    error BLOCK_NUMBER_MISMATCH();
    error REPORT_USED();
    error PROVER_TYPE_MISMATCH();
    error PROVER_INVALID_INSTANCE_ID(uint256);
    error PROVER_INVALID_ADDR(address);
    error PROVER_ADDR_MISMATCH(address, address);
    error PROVER_OUT_OF_DATE(uint256);

    event InstanceAdded(
        uint256 indexed id, address indexed instance, address replaced, uint256 validUntil
    );

    AttestationVerifier public verifier;
    uint256 public attestValiditySeconds;
    uint256 public maxBlockNumberDiff;
    uint256 public chainID;
    uint256 public nextInstanceId = 0;

    mapping(bytes32 reportHash => bool used) public attestedReports;
    mapping(uint256 proverInstanceID => ProverInstance instance) public attestedProvers;

    uint256[43] private __gap;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _initialOwner,
        address _verifierAddr,
        address _rollupAddressManager,
        uint256 _chainID,
        uint256 _attestValiditySeconds,
        uint256 _maxBlockNumberDiff
    )
        public
        initializer
    {
        verifier = AttestationVerifier(_verifierAddr);
        chainID = _chainID;
        attestValiditySeconds = _attestValiditySeconds;
        maxBlockNumberDiff = _maxBlockNumberDiff;
        __Essential_init(_initialOwner, _rollupAddressManager);
    }

    function reinitialize(
        uint8 i,
        address _initialOwner,
        address _verifierAddr,
        uint256 _chainID,
        uint256 _attestValiditySeconds,
        uint256 _maxBlockNumberDiff
    )
        public
        reinitializer(i)
    {
        verifier = AttestationVerifier(_verifierAddr);
        chainID = _chainID;
        attestValiditySeconds = _attestValiditySeconds;
        maxBlockNumberDiff = _maxBlockNumberDiff;
        _transferOwnership(_initialOwner);
    }

    /// @notice register prover instance with quote
    function register(bytes calldata _report, ReportData calldata _data) external {
        _checkBlockNumber(_data.referenceBlockNumber, _data.referenceBlockHash);
        bytes32 dataHash = keccak256(abi.encode(_data));

        verifier.verifyAttestation(_report, dataHash);

        bytes32 reportHash = keccak256(_report);
        if (attestedReports[reportHash]) revert REPORT_USED();
        attestedReports[reportHash] = true;

        uint256 instanceID = nextInstanceId + 1;
        nextInstanceId += 1;

        uint256 validUnitl = block.timestamp + attestValiditySeconds;
        attestedProvers[instanceID] = ProverInstance(_data.addr, validUnitl, _data.teeType);

        emit InstanceAdded(instanceID, _data.addr, address(0), validUnitl);
    }

    function checkProver(
        uint256 _instanceID,
        address _proverAddr
    )
        public
        view
        returns (ProverInstance memory)
    {
        ProverInstance memory prover;
        if (_instanceID == 0) revert PROVER_INVALID_INSTANCE_ID(_instanceID);
        if (_proverAddr == address(0)) revert PROVER_INVALID_ADDR(_proverAddr);
        prover = attestedProvers[_instanceID];
        if (prover.addr != _proverAddr) revert PROVER_ADDR_MISMATCH(prover.addr, _proverAddr);
        if (prover.validUntil < block.timestamp) revert PROVER_OUT_OF_DATE(prover.validUntil);
        return prover;
    }

    // Due to the inherent unpredictability of blockHash, it mitigates the risk of mass-generation
    //   of attestation reports in a short time frame, preventing their delayed and gradual
    // exploitation.
    // This function will make sure the attestation report generated in recent ${maxBlockNumberDiff}
    // blocks
    function _checkBlockNumber(uint256 blockNumber, bytes32 blockHash) private view {
        if (blockNumber >= block.number) revert INVALID_BLOCK_NUMBER();
        if (block.number - blockNumber >= maxBlockNumberDiff) {
            revert BLOCK_NUMBER_OUT_OF_DATE();
        }
        if (blockhash(blockNumber) != blockHash) revert BLOCK_NUMBER_MISMATCH();
    }

    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
    {
        // Do not run proof verification to contest an existing proof
        if (_ctx.isContesting) return;

        // Size is: 89 bytes
        // 4 bytes + 20 bytes + 65 bytes (signature) = 89
        // TODO: do we need this check?
        // if (_proof.data.length != 89) revert SGX_INVALID_PROOF();

        uint32 id = uint32(bytes4(_proof.data[:4]));
        address newInstance = address(bytes20(_proof.data[4:24]));

        address oldInstance = ECDSA.recover(
            LibPublicInput.hashPublicInputs(
                _tran, address(this), newInstance, _ctx.prover, _ctx.metaHash, taikoChainId()
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

    /// @inheritdoc IVerifier
    function verifyBatchProof(
        ContextV2[] calldata, /*_ctxs*/
        TaikoData.TierProof calldata /*_proof*/
    )
        external
        view
    { }

    function taikoChainId() internal view virtual returns (uint64) {
        return ITaikoL1(resolve(LibStrings.B_TAIKO, false)).getConfig().chainId;
    }
}
