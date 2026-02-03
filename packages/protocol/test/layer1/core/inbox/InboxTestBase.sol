// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { MockProofVerifier } from "./mocks/MockContracts.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { ProverWhitelist } from "src/layer1/core/impl/ProverWhitelist.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { PreconfWhitelist } from "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { MockBeaconBlockRoot } from "test/layer1/preconf/mocks/MockBeaconBlockRoot.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxTestBase
/// @notice Shared setup and helpers for Inbox tests.
abstract contract InboxTestBase is CommonTest {
    struct ProposedEvent {
        uint48 id;
        address proposer;
        bytes32 parentProposalHash;
        uint48 endOfSubmissionWindowTimestamp;
        uint8 basefeeSharingPctg;
        IInbox.DerivationSource[] sources;
    }

    Inbox internal inbox;
    IInbox.Config internal config;
    ICodec internal codec;

    MockProofVerifier internal verifier;
    SignalService internal signalService;
    PreconfWhitelist internal proposerChecker;
    ProverWhitelist internal proverWhitelistContract;
    TestERC20 internal bondToken;

    address internal proposer = Bob;
    address internal prover = Carol;

    uint48 internal constant INITIAL_BLOCK_NUMBER = 100;
    uint48 internal constant INITIAL_BLOCK_TIMESTAMP = 1000;
    address internal constant REMOTE_SIGNAL_SERVICE = address(0xdead);
    uint64 internal constant MIN_BOND_GWEI = 10_000_000_000;
    uint64 internal constant LIVENESS_BOND_GWEI = 2_000_000_000;
    uint48 internal constant WITHDRAWAL_DELAY = 7 days;

    function setUp() public virtual override {
        super.setUp();
        vm.deal(address(this), 100 ether);
        vm.deal(proposer, 100 ether);
        vm.deal(prover, 100 ether);

        _mockBeaconBlockRoot();
        _setupMocks();
        _setupDependencies();

        bondToken = new TestERC20("Bond Token", "BOND");
        config = _buildConfig();
        inbox = _deployInbox();
        codec = ICodec(address(inbox));
        _setSignalServiceSyncer(address(inbox));
        inbox.activate(bytes32(uint256(1)));

        _seedBondBalances();

        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_BLOCK_TIMESTAMP);
    }

    // ---------------------------------------------------------------
    // Hooks (internal virtual - state-changing)
    // ---------------------------------------------------------------

    function _buildConfig() internal virtual returns (IInbox.Config memory) {
        return IInbox.Config({
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            proverWhitelist: address(proverWhitelistContract),
            signalService: address(signalService),
            bondToken: address(bondToken),
            minBond: MIN_BOND_GWEI,
            livenessBond: LIVENESS_BOND_GWEI,
            withdrawalDelay: WITHDRAWAL_DELAY,
            provingWindow: 2 hours,
            permissionlessProvingDelay: 24 hours,
            maxProofSubmissionDelay: 3 minutes,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            forcedInclusionDelay: 384 seconds,
            forcedInclusionFeeInGwei: 10_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            permissionlessInclusionMultiplier: 5
        });
    }

    function _deployInbox() internal virtual returns (Inbox) {
        address impl = address(new Inbox(config));
        return _deployProxy(impl);
    }

    function _setupMocks() internal virtual {
        verifier = new MockProofVerifier();
    }

    function _setupDependencies() internal virtual {
        signalService = _deploySignalService(address(this));
        proposerChecker = _deployProposerChecker();
        proverWhitelistContract = _deployProverWhitelist();
        _addProposer(proposer);
    }

    // ---------------------------------------------------------------
    // Deploy helpers (internal - state-changing)
    // ---------------------------------------------------------------

    function _deployProxy(address _impl) internal returns (Inbox) {
        return Inbox(address(new ERC1967Proxy(_impl, abi.encodeCall(Inbox.init, (address(this))))));
    }

    function _deploySignalService(address _authorizedSyncer) internal returns (SignalService) {
        SignalService impl = new SignalService(_authorizedSyncer, REMOTE_SIGNAL_SERVICE);
        return SignalService(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(SignalService.init, (address(this))))
            )
        );
    }

    function _setSignalServiceSyncer(address _authorizedSyncer) internal {
        signalService.upgradeTo(
            address(new SignalService(_authorizedSyncer, REMOTE_SIGNAL_SERVICE))
        );
    }

    function _deployProposerChecker() internal returns (PreconfWhitelist) {
        PreconfWhitelist impl = new PreconfWhitelist();
        return PreconfWhitelist(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeCall(PreconfWhitelist.init, (address(this)))
                )
            )
        );
    }

    function _deployProverWhitelist() internal returns (ProverWhitelist) {
        ProverWhitelist impl = new ProverWhitelist();
        return ProverWhitelist(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeCall(ProverWhitelist.init, (address(this)))
                )
            )
        );
    }

    function _addProposer(address _proposer) internal {
        proposerChecker.addOperator(_proposer, _proposer);
    }

    // ---------------------------------------------------------------------
    // Block helpers (internal - state-changing)
    // ---------------------------------------------------------------------

    function _advanceBlock() internal {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }

    function _setBlobHashes(uint256 _count) internal {
        vm.blobhashes(_getBlobHashes(_count));
    }

    // ---------------------------------------------------------------------
    // Propose helpers (internal - state-changing)
    // ---------------------------------------------------------------------

    function _proposeOne() internal returns (ProposedEvent memory payload_) {
        _setBlobHashes(3);
        payload_ = _proposeAndDecode(_defaultProposeInput());
    }

    function _proposeAndDecode(IInbox.ProposeInput memory _input)
        internal
        returns (ProposedEvent memory payload_)
    {
        assertEq(proposerChecker.operatorCount(), 1, "proposer count (propose)");
        assertEq(
            proposerChecker.getOperatorForCurrentEpoch(), proposer, "active proposer (propose)"
        );
        proposerChecker.checkProposer(proposer, bytes(""));
        payload_ = _proposeAndDecodeWithGas(_input, "");
    }

    function _proposeAndDecodeWithGas(
        IInbox.ProposeInput memory _input,
        string memory _benchName
    )
        internal
        returns (ProposedEvent memory payload_)
    {
        bytes memory encodedInput = codec.encodeProposeInput(_input);
        vm.recordLogs();
        vm.startPrank(proposer);

        if (bytes(_benchName).length > 0) vm.startSnapshotGas("shasta-propose", _benchName);
        inbox.propose(bytes(""), encodedInput);
        if (bytes(_benchName).length > 0) vm.stopSnapshotGas();

        vm.stopPrank();
        payload_ = _readProposedEvent();
    }

    function _readProposedEvent() internal returns (ProposedEvent memory payload_) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length > 0, "Proposed event not found");
        Vm.Log memory log = logs[logs.length - 1];

        payload_.id = uint48(uint256(log.topics[1]));
        payload_.proposer = address(uint160(uint256(log.topics[2])));
        (
            payload_.parentProposalHash,
            payload_.endOfSubmissionWindowTimestamp,
            payload_.basefeeSharingPctg,
            payload_.sources
        ) = abi.decode(log.data, (bytes32, uint48, uint8, IInbox.DerivationSource[]));
    }

    function _mockBeaconBlockRoot() internal {
        vm.etch(
            LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT, address(new MockBeaconBlockRoot()).code
        );
    }

    function _seedBondBalances() internal {
        uint64 initialBond = MIN_BOND_GWEI + LIVENESS_BOND_GWEI;

        bondToken.mint(proposer, _toTokenAmount(initialBond));
        bondToken.mint(prover, _toTokenAmount(initialBond));
        bondToken.mint(David, _toTokenAmount(initialBond));

        vm.startPrank(proposer);
        bondToken.approve(address(inbox), type(uint256).max);
        inbox.deposit(initialBond);
        vm.stopPrank();

        vm.startPrank(prover);
        bondToken.approve(address(inbox), type(uint256).max);
        inbox.deposit(initialBond);
        vm.stopPrank();

        vm.startPrank(David);
        bondToken.approve(address(inbox), type(uint256).max);
        inbox.deposit(initialBond);
        vm.stopPrank();
    }

    function _toTokenAmount(uint64 _amount) internal pure returns (uint256) {
        return uint256(_amount) * 1 gwei;
    }

    // ---------------------------------------------------------------------
    // Prove helpers (internal - state-changing)
    // ---------------------------------------------------------------------

    function _prove(IInbox.ProveInput memory _input) internal {
        _proveWithGas(_input, "", "");
    }

    function _proveWithGas(
        IInbox.ProveInput memory _input,
        string memory _profile,
        string memory _benchName
    )
        internal
    {
        bytes memory encodedInput = codec.encodeProveInput(_input);
        vm.startPrank(prover);

        if (bytes(_benchName).length > 0) vm.startSnapshotGas(_profile, _benchName);
        inbox.prove(encodedInput, bytes("proof"));
        if (bytes(_benchName).length > 0) vm.stopSnapshotGas();

        vm.stopPrank();
    }

    function _buildBatchInput(uint256 _count) internal returns (IInbox.ProveInput memory input_) {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](_count);

        uint48 firstProposalId;
        uint48 proposalTimestamp;

        for (uint256 i; i < _count; ++i) {
            if (i != 0) _advanceBlock();
            ProposedEvent memory payload = _proposeOne();

            if (i == 0) {
                firstProposalId = payload.id;
            }
            proposalTimestamp = uint48(block.timestamp);

            bytes32 blockHash = keccak256(abi.encode("blockHash", i + 1));
            transitions[i] = _transitionFor(payload, proposalTimestamp, blockHash);
        }

        // Get the last proposal hash from the ring buffer
        uint256 lastProposalId = firstProposalId + _count - 1;
        bytes32 lastProposalHash = inbox.getProposalHash(lastProposalId);

        input_ = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: firstProposalId,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: lastProposalHash,
                actualProver: prover,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256(abi.encode("stateRoot", _count)),
                transitions: transitions
            })
        });
    }

    // ---------------------------------------------------------------------
    // Pure helpers
    // ---------------------------------------------------------------------

    function _getBlobHashes(uint256 _count) internal pure returns (bytes32[] memory hashes_) {
        hashes_ = new bytes32[](_count);
        for (uint256 i; i < _count; ++i) {
            hashes_[i] = keccak256(abi.encode("blob", i));
        }
    }

    function _defaultProposeInput() internal pure returns (IInbox.ProposeInput memory input_) {
        input_.deadline = 0;
        input_.blobReference = LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 });
    }

    function _proposalFromPayload(
        ProposedEvent memory _payload,
        uint48 _timestamp,
        uint48 _originBlockNumber,
        bytes32 _originBlockHash
    )
        internal
        view
        returns (IInbox.Proposal memory proposal_)
    {
        bytes32 parentProposalHash =
            _payload.id == 0 ? bytes32(0) : inbox.getProposalHash(_payload.id - 1);

        proposal_ = IInbox.Proposal({
            id: _payload.id,
            timestamp: _timestamp,
            endOfSubmissionWindowTimestamp: _payload.endOfSubmissionWindowTimestamp,
            proposer: _payload.proposer,
            parentProposalHash: parentProposalHash,
            originBlockNumber: _originBlockNumber,
            originBlockHash: _originBlockHash,
            basefeeSharingPctg: _payload.basefeeSharingPctg,
            sources: _payload.sources
        });
    }

    function _transitionFor(
        ProposedEvent memory _payload,
        uint48 _proposalTimestamp,
        bytes32 _blockHash
    )
        internal
        pure
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposer: _payload.proposer, timestamp: _proposalTimestamp, blockHash: _blockHash
        });
    }

    function _assertStateEqual(
        IInbox.CoreState memory _actual,
        IInbox.CoreState memory _expected
    )
        internal
        pure
    {
        assertEq(_actual.nextProposalId, _expected.nextProposalId, "state nextProposalId");
        assertEq(_actual.lastProposalBlockId, _expected.lastProposalBlockId, "state last block");
        assertEq(
            _actual.lastFinalizedProposalId, _expected.lastFinalizedProposalId, "state finalized id"
        );
        assertEq(
            _actual.lastFinalizedTimestamp, _expected.lastFinalizedTimestamp, "state finalized ts"
        );
        assertEq(
            _actual.lastCheckpointTimestamp,
            _expected.lastCheckpointTimestamp,
            "state checkpoint ts"
        );
        assertEq(
            _actual.lastFinalizedBlockHash,
            _expected.lastFinalizedBlockHash,
            "state transition hash"
        );
    }
}
