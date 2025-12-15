// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Codec } from "src/layer1/core/impl/Codec.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { ProverWhitelist } from "src/layer1/core/impl/ProverWhitelist.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

contract InboxWhitelistProverTest is InboxTestBase {
    address internal whitelistedProver = address(0x1234);
    ProverWhitelist internal proverWhitelist;

    // ---------------------------------------------------------------
    // Hooks (internal override - state-changing)
    // ---------------------------------------------------------------

    function _buildConfig() internal override returns (IInbox.Config memory) {
        codec = ICodec(new Codec());

        // Deploy and setup ProverWhitelist
        ProverWhitelist proverWhitelistImpl = new ProverWhitelist();
        proverWhitelist = ProverWhitelist(
            address(
                new ERC1967Proxy(
                    address(proverWhitelistImpl),
                    abi.encodeCall(ProverWhitelist.init, (address(this)))
                )
            )
        );
        proverWhitelist.whitelistProver(whitelistedProver, true);

        return IInbox.Config({
            codec: address(codec),
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            proverWhitelist: address(proverWhitelist),
            signalService: address(signalService),
            provingWindow: 2 hours,
            maxProofSubmissionDelay: 3 minutes,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 384,
            forcedInclusionFeeInGwei: 10_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            minCheckpointDelay: 60_000,
            permissionlessInclusionMultiplier: 5
        });
    }

    // ---------------------------------------------------------------
    // Tests (public - state-changing)
    // ---------------------------------------------------------------

    function test_prove_succeedsWhen_CallerIsWhitelistedProver() public {
        IInbox.ProveInput memory input = _buildBatchInputWithProver(1, whitelistedProver);

        _proveAs(whitelistedProver, input);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.commitment.firstProposalId, "finalized id");
    }

    function test_prove_skipsBondInstruction_whenCallerIsWhitelistedProver() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();

        // Warp past proving window to ensure bond would normally be emitted
        vm.warp(block.timestamp + config.provingWindow + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: p1.proposal.proposer,
            designatedProver: proposer, // Different from actual to trigger bond
            timestamp: p1.proposal.timestamp,
            blockHash: keccak256("checkpoint1")
        });

        IInbox.ProveInput memory input = _buildInputWithProver(
            p1.proposal.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            transitions,
            whitelistedProver
        );

        _proveAs(whitelistedProver, input);

        // Verify no bond signal was sent (whitelisted prover skips bond calculation)
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: p1.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer, // designated prover
            payee: whitelistedProver
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);
        assertFalse(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "no bond signal for whitelisted prover"
        );
    }

    function test_prove_RevertWhen_CallerIsNotWhitelistedProver() public {
        IInbox.ProveInput memory input = _buildBatchInputWithProver(1, prover);

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.ProverNotWhitelisted.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // ---------------------------------------------------------------------
    // Helpers (private - state-changing)
    // ---------------------------------------------------------------------

    function _proveAs(address _proverAddr, IInbox.ProveInput memory _input) private {
        bytes memory encodedInput = codec.encodeProveInput(_input);
        vm.prank(_proverAddr);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function _buildBatchInputWithProver(
        uint256 _count,
        address _actualProver
    )
        private
        returns (IInbox.ProveInput memory input_)
    {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](_count);

        uint48 firstProposalId;

        for (uint256 i; i < _count; ++i) {
            if (i != 0) _advanceBlock();
            IInbox.ProposedEventPayload memory payload = _proposeOne();

            if (i == 0) {
                firstProposalId = payload.proposal.id;
            }

            bytes32 blockHash = keccak256(abi.encode("checkpoint", i + 1));
            transitions[i] = IInbox.Transition({
                proposer: payload.proposal.proposer,
                designatedProver: _actualProver,
                timestamp: payload.proposal.timestamp,
                blockHash: blockHash
            });
        }

        uint256 lastProposalId = firstProposalId + _count - 1;
        bytes32 lastProposalHash = inbox.getProposalHash(lastProposalId);

        input_ = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: firstProposalId,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: lastProposalHash,
                actualProver: _actualProver,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256(abi.encode("stateRoot", _count)),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });
    }

    // ---------------------------------------------------------------------
    // Helpers (private view)
    // ---------------------------------------------------------------------

    function _buildInputWithProver(
        uint48 _firstProposalId,
        bytes32 _parentBlockHash,
        IInbox.Transition[] memory _transitions,
        address _actualProver
    )
        private
        view
        returns (IInbox.ProveInput memory)
    {
        uint256 lastProposalId = _firstProposalId + _transitions.length - 1;
        return IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: _firstProposalId,
                firstProposalParentBlockHash: _parentBlockHash,
                lastProposalHash: inbox.getProposalHash(lastProposalId),
                actualProver: _actualProver,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256(abi.encode("stateRoot")),
                transitions: _transitions
            }),
            forceCheckpointSync: false
        });
    }
}
