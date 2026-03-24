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
        bytes calldata _lookahead
    )
        internal
        override
        returns (uint48 result_)
    {
        address checker = address(_proposerChecker);
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0xac0004da00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), _sender)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), _lookahead.length)
            calldatacopy(add(ptr, 0x64), _lookahead.offset, _lookahead.length)

            if iszero(
                staticcall(gas(), checker, ptr, add(0x64, _lookahead.length), ptr, 0x20)
            ) {
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            result_ := mload(ptr)
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

    /// @notice Measures propose() gas with real PreconfWhitelist, SignalService,
    /// and ring buffer reuse after finalization — matching real mainnet steady state.
    function test_mainnetInbox_propose_gas() public {
        _setBlobHashes(8);

        // Phase 1: Propose 2 blocks then prove them to free capacity.
        // genesis=id0 at slot 0, proposal id=1 at slot 1, id=2 at slot 2
        ProposedEvent memory p1 = _proposeAndDecode(_defaultProposeInput());
        uint48 p1Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p2 = _proposeAndDecode(_defaultProposeInput());
        uint48 p2Timestamp = uint48(block.timestamp);

        // Prove 1-2 → lastFinalizedProposalId=2, nextProposalId=3
        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(p1, p1Timestamp, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(p2, p2Timestamp, keccak256("blockHash2"));

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: p1.id,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(p2.id),
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
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());

        // Phase 3: Measured propose — id=6 writes to slot 6%5=1 (nonzero from proposal 1).
        // Capacity: rbs(5) > 6-2=4 ✓. Steady-state: nonzero→nonzero SSTORE.
        _advanceBlock();
        _proposeAndDecodeWithGas(_defaultProposeInput(), "mainnet_propose");
    }
}
