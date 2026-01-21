// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { ProverWhitelist } from "src/layer1/core/impl/ProverWhitelist.sol";

contract InboxWhitelistProverTest is InboxTestBase {
    address internal whitelistedProver = address(0x1234);
    ProverWhitelist internal proverWhitelist;

    // ---------------------------------------------------------------
    // Hooks (internal override - state-changing)
    // ---------------------------------------------------------------

    function _buildConfig() internal override returns (IInbox.Config memory) {
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

        IInbox.Config memory cfg = super._buildConfig();
        cfg.proverWhitelist = address(proverWhitelist);
        return cfg;
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
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);

        // Warp past proving window to ensure bond would normally be emitted
        vm.warp(block.timestamp + config.provingWindow + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: p1.proposer, timestamp: p1Timestamp, blockHash: keccak256("checkpoint1")
        });

        IInbox.ProveInput memory input = _buildInputWithProver(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, transitions, whitelistedProver
        );

        uint64 proposerBalanceBefore = inbox.getBond(proposer).balance;
        uint64 whitelistedBalanceBefore = inbox.getBond(whitelistedProver).balance;

        _proveAs(whitelistedProver, input);

        assertEq(
            uint256(inbox.getBond(proposer).balance),
            uint256(proposerBalanceBefore),
            "no bond change for proposer"
        );
        assertEq(
            uint256(inbox.getBond(whitelistedProver).balance),
            uint256(whitelistedBalanceBefore),
            "no bond change for whitelisted prover"
        );
    }

    function test_prove_succeedsWhen_CallerIsNotWhitelistedProverAndProposalIsTooOld() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);

        vm.warp(uint256(p1Timestamp) + config.permissionlessProvingDelay + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: p1.proposer, timestamp: p1Timestamp, blockHash: keccak256("checkpoint1")
        });

        IInbox.ProveInput memory input = _buildInputWithProver(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, transitions, prover
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, p1.id, "finalized id");
    }

    function test_prove_RevertWhen_CallerIsNotWhitelistedProverAndProposalTooYoung() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);

        vm.warp(uint256(p1Timestamp) + config.provingWindow + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: p1.proposer, timestamp: p1Timestamp, blockHash: keccak256("checkpoint1")
        });

        IInbox.ProveInput memory input = _buildInputWithProver(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, transitions, prover
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.ProverNotWhitelisted.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
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
            ProposedEvent memory payload = _proposeOne();
            uint48 proposalTimestamp = uint48(block.timestamp);

            if (i == 0) {
                firstProposalId = payload.id;
            }

            bytes32 blockHash = keccak256(abi.encode("checkpoint", i + 1));
            transitions[i] = IInbox.Transition({
                proposer: payload.proposer, timestamp: proposalTimestamp, blockHash: blockHash
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
            })
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
            })
        });
    }
}
