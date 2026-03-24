// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibFasterReentryLock } from "src/layer1/mainnet/LibFasterReentryLock.sol";

/// @dev Test-only Inbox that mirrors MainnetInbox's runtime optimizations (transient reentrancy
/// lock, assembly _checkProposer) but accepts an arbitrary Config — letting us use a small
/// ringBufferSize so the measured propose overwrites a non-zero slot (steady-state SSTORE cost).
contract TestMainnetInbox is Inbox {
    constructor(Config memory _config) Inbox(_config) { }

    function _checkProposer(
        address _sender,
        bytes calldata
    )
        internal
        override
        returns (uint48 result_)
    {
        address checker = address(_proposerChecker);
        assembly {
            let ptr := mload(0x40)
            // checkProposerMinimal(address) — selector 0xff7a9297
            mstore(ptr, 0xff7a929700000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), _sender)

            if iszero(staticcall(gas(), checker, ptr, 0x24, 0x00, 0x00)) {
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            result_ := 0
        }
    }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}

/// @notice Gas test for MainnetInbox.propose() with real-world deployment dependencies.
/// Uses actual PreconfWhitelist, ProverWhitelist, and SignalService — not mocks.
/// Config matches MainnetInbox values (minBond=0, basefeeSharingPctg=75) but uses a small
/// ringBufferSize (5) so the measured propose overwrites a non-zero slot — matching steady state.
contract MainnetInboxGasTest is InboxTestBase {
    /// @dev Ring buffer size for test — small enough that the measured propose (id=6) wraps
    /// around to slot 6%5=1, which already holds proposal 1's hash (nonzero→nonzero SSTORE).
    uint48 private constant _TEST_RING_BUFFER_SIZE = 5;

    function _buildConfig() internal override returns (IInbox.Config memory cfg) {
        cfg = IInbox.Config({
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            proverWhitelist: address(proverWhitelistContract),
            signalService: address(signalService),
            bondToken: address(bondToken),
            minBond: 0,
            livenessBond: 0,
            withdrawalDelay: 1 weeks,
            provingWindow: 4 hours,
            permissionlessProvingDelay: 5 days,
            maxProofSubmissionDelay: 3 minutes,
            ringBufferSize: _TEST_RING_BUFFER_SIZE,
            basefeeSharingPctg: 75,
            forcedInclusionDelay: 576 seconds,
            forcedInclusionFeeInGwei: 1_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            permissionlessInclusionMultiplier: 160
        });
    }

    function _deployInbox() internal override returns (Inbox) {
        // Use TestMainnetInbox: same optimizations as MainnetInbox but with configurable
        // ringBufferSize so we can force ring buffer wrap-around in the test.
        address impl = address(new TestMainnetInbox(_buildConfig()));
        return _deployProxy(impl);
    }

    /// @dev Propose without event decoding — for warmup proposes that emit ProposedFast.
    function _proposeRaw() internal {
        bytes memory encodedInput = codec.encodeProposeInput(_defaultProposeInput());
        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);
    }

    /// @dev Propose with gas measurement only — no event decoding needed.
    function _proposeWithGas(string memory _benchName) internal {
        // Packed: deadline(48)=0 | blobStartIndex(16)=0 | numBlobs(16)=1 | blobOffset(24)=0
        uint256 packedInput = uint256(1) << 176; // numBlobs=1 at bits 176-191
        vm.startPrank(proposer);
        vm.startSnapshotGas("shasta-propose", _benchName);
        inbox.proposeFast(packedInput);
        vm.stopSnapshotGas();
        vm.stopPrank();
    }

    /// @notice Measures propose() gas with real PreconfWhitelist, SignalService,
    /// and ring buffer reuse after finalization — matching real mainnet steady state.
    function test_mainnetInbox_propose_gas() public {
        _setBlobHashes(8);

        // Phase 1: Propose 2 blocks then prove them to free capacity.
        // genesis=id0 at slot 0, proposal id=1 at slot 1, id=2 at slot 2
        _proposeRaw();
        uint48 p1Timestamp = uint48(block.timestamp);
        _advanceBlock();
        _proposeRaw();
        uint48 p2Timestamp = uint48(block.timestamp);

        // Prove 1-2 → lastFinalizedProposalId=2, nextProposalId=3
        // _transitionFor only needs proposer, which we know
        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            proposer: proposer, timestamp: p1Timestamp, blockHash: keccak256("checkpoint1")
        });
        transitions[1] = IInbox.Transition({
            proposer: proposer, timestamp: p2Timestamp, blockHash: keccak256("blockHash2")
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 1, // first proposal after genesis
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(2),
                actualProver: prover,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256("stateRoot"),
                transitions: transitions
            })
        });

        _prove(proveInput);

        // Phase 2: Propose 3 more to fill remaining slots and wrap around.
        // id=3 → slot 3, id=4 → slot 4, id=5 → slot 0 (reuse genesis slot)
        _advanceBlock();
        _proposeRaw();
        _advanceBlock();
        _proposeRaw();
        _advanceBlock();
        _proposeRaw();

        // Phase 3: Measured propose — id=6 writes to slot 6%5=1 (nonzero from proposal 1).
        // Capacity: rbs(5) > 6-2=4 ✓. Steady-state: nonzero→nonzero SSTORE.
        _advanceBlock();
        _proposeWithGas("mainnet_propose");
    }
}
