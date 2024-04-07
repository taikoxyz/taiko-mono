// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestBase.sol";

contract TaikoL1New is TaikoL1 {
    function getConfig() public view override returns (TaikoData.Config memory config) {
        config = TaikoL1.getConfig();
        config.maxBlocksToVerifyPerProposal = 0;
        config.blockMaxProposals = 10;
        config.blockRingBufferSize = 20;
    }

    function _checkEOAForCalldataDA() internal pure override returns (bool) {
        return false;
    }
}

// contract Verifier {
//     fallback(bytes calldata) external returns (bytes memory) {
//         return bytes.concat(keccak256("taiko"));
//     }
// }

contract TaikoL1NewTest is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return TaikoL1(
            payable(deployProxy({ name: "taiko", impl: address(new TaikoL1New()), data: "" }))
        );
    }

    // Conventions:
    // Alice is always  the block proposer
    // Bob is always the assigned prover

    function test_additional__provedBy_assignedProver_inProofWindow() external {
        _printBlockAndTrans(0);

        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob);
        _printBlockAndTrans(meta.id);

        TaikoData.Block memory blk = L1.getBlock(meta.id);
        assertEq(blk.assignedProver, Bob);
        assertEq(blk.proposedAt, block.timestamp);
        assertEq(blk.nextTransitionId, 1);
        assertEq(blk.verifiedTransitionId, 0);
        assertTrue(blk.livenessBond != 0);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        proveBlock(Bob, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
        _printBlockAndTrans(meta.id);

        TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
        assertEq(ts.prover, Bob);
        assertEq(ts.blockHash, blockHash);
        assertEq(ts.stateRoot, stateRoot);
        assertTrue(ts.tier != 0);
        assertTrue(ts.contestBond == 1); // not zero
        assertTrue(ts.timestamp == block.timestamp); // not zero

        mine(1);
        vm.warp(block.timestamp + 7 days);
        verifyBlock(2);
        _printBlockAndTrans(meta.id);
    }

    function proposeBlock(
        address proposer,
        address assignedProver
    )
        internal
        returns (TaikoData.BlockMetadata memory meta)
    {
        giveEthAndTko(proposer, 10_000 ether, 10_000 ether);
        giveEthAndTko(assignedProver, 10_000 ether, 10_000 ether);
        console2.log("-----------------------");

        TaikoData.TierFee[] memory tierFees = new TaikoData.TierFee[](2);
        tierFees[0] = TaikoData.TierFee(LibTiers.TIER_OPTIMISTIC, 1 ether);
        tierFees[1] = TaikoData.TierFee(LibTiers.TIER_SGX, 2 ether);

        AssignmentHook.ProverAssignment memory assignment = AssignmentHook.ProverAssignment({
            feeToken: address(0),
            tierFees: tierFees,
            expiry: uint64(block.timestamp + 60 minutes),
            maxBlockId: 0,
            maxProposedIn: 0,
            metaHash: 0,
            parentMetaHash: 0,
            signature: new bytes(0)
        });

        bytes memory txList = new bytes(10);
        assignment.signature =
            _signAssignment(assignedProver, assignment, address(L1), keccak256(txList));

        TaikoData.HookCall[] memory hookcalls = new TaikoData.HookCall[](1);
        hookcalls[0] = TaikoData.HookCall(address(assignmentHook), abi.encode(assignment));

        vm.prank(proposer);
        (meta,) = L1.proposeBlock{ value: 3 ether }(
            abi.encode(TaikoData.BlockParams(assignedProver, address(0), 0, 0, hookcalls, "")),
            txList
        );
    }

    function _printBlockAndTrans(uint64 blockId) private view {
        TaikoData.Block memory blk = L1.getBlock(blockId);
        _printBlock(blk);

        for (uint32 i = 1; i < blk.nextTransitionId; ++i) {
            _printTran(i, L1.getTransition(blockId, i));
        }
    }

    function _printBlock(TaikoData.Block memory blk) private view {
        TaikoData.SlotB memory b = L1.slotB();
        console2.log("\n==================================");
        console2.log("---CHAIN:");
        console2.log(" | lastVerifiedBlockId:", b.lastVerifiedBlockId);
        console2.log(" | numBlocks:", b.numBlocks);
        console2.log(" | timestamp:", block.timestamp);
        console2.log("---BLOCK#", blk.blockId);
        console2.log(" | assignedProver:", blk.assignedProver);
        console2.log(" | livenessBond:", blk.livenessBond);
        console2.log(" | proposedAt:", blk.proposedAt);
        console2.log(" | metaHash:", vm.toString(blk.metaHash));
        console2.log(" | nextTransitionId:", blk.nextTransitionId);
        console2.log(" | verifiedTransitionId:", blk.verifiedTransitionId);
    }

    function _printTran(uint64 tid, TaikoData.TransitionState memory ts) private pure {
        console2.log(" |---TRANSITION#", tid);
        console2.log("   | tier:", ts.tier);
        console2.log("   | prover:", ts.prover);
        console2.log("   | validityBond:", ts.validityBond);
        console2.log("   | contester:", ts.contester);
        console2.log("   | contestBond:", ts.contestBond);
        console2.log("   | timestamp:", ts.timestamp);
        console2.log("   | blockHash:", vm.toString(ts.blockHash));
        console2.log("   | stateRoot:", vm.toString(ts.stateRoot));
    }
}
