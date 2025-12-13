// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { MockProofVerifier } from "./mocks/MockContracts.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Codec } from "src/layer1/core/impl/Codec.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { ProverWhitelist } from "src/layer1/core/impl/ProverWhitelist.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { PreconfWhitelist } from "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxTestBase
/// @notice Shared setup and helpers for Inbox tests.
abstract contract InboxTestBase is CommonTest {
    Inbox internal inbox;
    IInbox.Config internal config;
    ICodec internal codec;

    MockProofVerifier internal verifier;
    SignalService internal signalService;
    PreconfWhitelist internal proposerChecker;
    ProverWhitelist internal proverWhitelistContract;

    address internal proposer = Bob;
    address internal prover = Carol;

    uint48 internal constant INITIAL_BLOCK_NUMBER = 100;
    uint48 internal constant INITIAL_BLOCK_TIMESTAMP = 1000;
    address internal constant REMOTE_SIGNAL_SERVICE = address(0xdead);

    function setUp() public virtual override {
        super.setUp();
        vm.deal(address(this), 100 ether);
        vm.deal(proposer, 100 ether);
        vm.deal(prover, 100 ether);

        _setupMocks();
        _setupDependencies();

        config = _buildConfig();
        inbox = _deployInbox();
        _setSignalServiceSyncer(address(inbox));
        inbox.activate(bytes32(uint256(1)));

        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_BLOCK_TIMESTAMP);
    }

    // ---------------------------------------------------------------
    // Hooks (internal virtual - state-changing)
    // ---------------------------------------------------------------

    function _buildConfig() internal virtual returns (IInbox.Config memory) {
        codec = ICodec(new Codec());

        return IInbox.Config({
            codec: address(codec),
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            proverWhitelist: address(proverWhitelistContract),
            signalService: address(signalService),
            provingWindow: 2 hours,
            extendedProvingWindow: 4 hours,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 384,
            forcedInclusionFeeInGwei: 10_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            minCheckpointDelay: 60_000, // large enough for skipping checkpoints in prove benches
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
        SignalService impl = new SignalService(_authorizedSyncer, REMOTE_SIGNAL_SERVICE, block.timestamp + 365 days);
        return SignalService(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(SignalService.init, (address(this))))
            )
        );
    }

    function _setSignalServiceSyncer(address _authorizedSyncer) internal {
        signalService.upgradeTo(
            address(new SignalService(_authorizedSyncer, REMOTE_SIGNAL_SERVICE, block.timestamp + 365 days))
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

    function _proposeOne() internal returns (IInbox.ProposedEventPayload memory payload_) {
        _setBlobHashes(3);
        payload_ = _proposeAndDecode(_defaultProposeInput());
    }

    function _proposeAndDecode(IInbox.ProposeInput memory _input)
        internal
        returns (IInbox.ProposedEventPayload memory payload_)
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
        returns (IInbox.ProposedEventPayload memory payload_)
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

    function _readProposedEvent() internal returns (IInbox.ProposedEventPayload memory payload_) {
        bytes memory eventData = _findEventData(keccak256("Proposed(bytes)"));
        require(eventData.length > 0, "Proposed event not found");
        return codec.decodeProposedEvent(eventData);
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

        for (uint256 i; i < _count; ++i) {
            if (i != 0) _advanceBlock();
            IInbox.ProposedEventPayload memory payload = _proposeOne();

            if (i == 0) {
                firstProposalId = payload.proposal.id;
            }

            // Generate a unique checkpoint for this proposal and hash it
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: keccak256(abi.encode("blockHash", i + 1)),
                stateRoot: keccak256(abi.encode("stateRoot", i + 1))
            });
            bytes32 blockHash = keccak256(abi.encode(checkpoint));
            transitions[i] = _transitionFor(payload, prover, blockHash);
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
            }),
            forceCheckpointSync: false
        });
    }

    // ---------------------------------------------------------------------
    // Private helpers (state-changing)
    // ---------------------------------------------------------------------

    function _findEventData(bytes32 _topic) private returns (bytes memory) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length != 0 && logs[i].topics[0] == _topic) {
                return abi.decode(logs[i].data, (bytes));
            }
        }
        return bytes("");
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
        input_.numForcedInclusions = 0;
    }

    function _transitionFor(
        IInbox.ProposedEventPayload memory _payload,
        address _designatedProver,
        bytes32 _blockHash
    )
        internal
        pure
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposer: _payload.proposal.proposer,
            designatedProver: _designatedProver,
            timestamp: _payload.proposal.timestamp,
            blockHash: _blockHash
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
