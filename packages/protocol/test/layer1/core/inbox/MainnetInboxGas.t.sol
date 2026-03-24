// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";

/// @notice Gas test for MainnetInbox.propose() with real-world deployment dependencies.
/// Uses actual PreconfWhitelist, ProverWhitelist, and SignalService — not mocks.
/// Config matches DeployShastaContracts.s.sol mainnet values (minBond=0, ringBufferSize=21600).
contract MainnetInboxGasTest is InboxTestBase {
    function _buildConfig() internal override returns (IInbox.Config memory cfg) {
        // Return a config that matches MainnetInbox constructor values.
        // Note: _deployInbox() overrides to use MainnetInbox directly, so
        // these values are only used for compatibility with InboxTestBase helpers.
        cfg = IInbox.Config({
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            proverWhitelist: address(proverWhitelistContract),
            signalService: address(signalService),
            bondToken: address(bondToken),
            minBond: 0, // Mainnet: no bonds during whitelist phase
            livenessBond: 0,
            withdrawalDelay: 1 weeks,
            provingWindow: 4 hours,
            permissionlessProvingDelay: 5 days,
            maxProofSubmissionDelay: 3 minutes,
            ringBufferSize: 21_600,
            basefeeSharingPctg: 75,
            forcedInclusionDelay: 576 seconds,
            forcedInclusionFeeInGwei: 1_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            permissionlessInclusionMultiplier: 160
        });
    }

    function _deployInbox() internal override returns (Inbox) {
        // Deploy MainnetInbox with real dependency addresses — matches DeployShastaContracts.s.sol
        address impl = address(
            new MainnetInbox(
                address(verifier),
                address(proposerChecker),
                address(proverWhitelistContract),
                address(signalService),
                address(bondToken)
            )
        );
        return _deployProxy(impl);
    }

    // Note: minBond=0 on mainnet, so bond deposits are unnecessary for propose().
    // _seedBondBalances() still runs (seeds bonds) but they won't affect gas measurement
    // since the bond check is skipped when minBond=0.

    /// @notice Measures propose() gas on MainnetInbox with real PreconfWhitelist, SignalService,
    /// and ring buffer reuse after finalization — matching real mainnet deployment.
    function test_mainnetInbox_propose_gas() public {
        // Use a small ring buffer subset for the test (we just need wrap-around)
        _setBlobHashes(6);

        // Propose 5 blocks
        ProposedEvent memory p1 = _proposeAndDecode(_defaultProposeInput());
        uint48 p1Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p2 = _proposeAndDecode(_defaultProposeInput());
        uint48 p2Timestamp = uint48(block.timestamp);
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());

        // Prove first 2 (finalize them to exercise warm storage paths)
        uint48 endBlockNumber = uint48(block.number);
        bytes32 endStateRoot = keccak256("stateRoot");
        bytes32 checkpoint2Hash = keccak256("blockHash2");

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(p1, p1Timestamp, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(p2, p2Timestamp, checkpoint2Hash);

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: p1.id,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(p2.id),
                actualProver: prover,
                endBlockNumber: endBlockNumber,
                endStateRoot: endStateRoot,
                transitions: transitions
            })
        });

        _prove(proveInput);

        // Propose after finalization — this is the steady-state hot path
        _advanceBlock();
        _proposeAndDecodeWithGas(_defaultProposeInput(), "mainnet_propose");
    }
}
