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
        return true;
    }
}

abstract contract TaikoL1TestGroupBase is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return TaikoL1(
            payable(deployProxy({ name: "taiko", impl: address(new TaikoL1New()), data: "" }))
        );
    }

    function proposeBlock(
        address proposer,
        address assignedProver,
        bytes4 revertReason
    )
        internal
        returns (TaikoData.BlockMetadata memory meta)
    {
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
            _signAssignment(assignedProver, assignment, address(L1), proposer, keccak256(txList));

        TaikoData.HookCall[] memory hookcalls = new TaikoData.HookCall[](1);
        hookcalls[0] = TaikoData.HookCall(address(assignmentHook), abi.encode(assignment));

        bytes memory eoaSig;
        {
            uint256 privateKey;
            if (proposer == Alice) {
                privateKey = 0x1;
            } else if (proposer == Bob) {
                privateKey = 0x2;
            } else if (proposer == Carol) {
                privateKey = 0x3;
            } else {
                revert("unexpected");
            }

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, keccak256(txList));
            eoaSig = abi.encodePacked(r, s, v);
        }

        vm.prank(proposer);
        if (revertReason != "") vm.expectRevert(revertReason);
        (meta,) = L1.proposeBlock{ value: 3 ether }(
            abi.encode(TaikoData.BlockParams(assignedProver, address(0), 0, 0, hookcalls, eoaSig)),
            txList
        );
    }

    function proveBlock(
        address prover,
        TaikoData.BlockMetadata memory meta,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 stateRoot,
        uint16 tier,
        bytes4 revertReason
    )
        internal
        override
    {
        TaikoData.Transition memory tran = TaikoData.Transition({
            parentHash: parentHash,
            blockHash: blockHash,
            stateRoot: stateRoot,
            graffiti: 0x0
        });

        TaikoData.TierProof memory proof;
        proof.tier = tier;
        address newInstance;

        // Keep changing the pub key associated with an instance to avoid
        // attacks,
        // obviously just a mock due to 2 addresses changing all the time.
        (newInstance,) = sv.instances(0);
        if (newInstance == SGX_X_0) {
            newInstance = SGX_X_1;
        } else {
            newInstance = SGX_X_0;
        }

        if (tier == LibTiers.TIER_SGX) {
            bytes memory signature =
                createSgxSignatureProof(tran, newInstance, prover, keccak256(abi.encode(meta)));

            proof.data = bytes.concat(bytes4(0), bytes20(newInstance), signature);
        }

        if (tier == LibTiers.TIER_GUARDIAN) {
            proof.data = "";

            // Grant 2 signatures, 3rd might be a revert
            vm.prank(David, David);
            gp.approve(meta, tran, proof);
            vm.prank(Emma, Emma);
            gp.approve(meta, tran, proof);

            if (revertReason != "") vm.expectRevert(revertReason);
            vm.prank(Frank);
            gp.approve(meta, tran, proof);
        } else {
            if (revertReason != "") vm.expectRevert(revertReason);
            vm.prank(prover);
            L1.proveBlock(meta.id, abi.encode(meta, tran, proof));
        }
    }

    function printBlockAndTrans(uint64 blockId) internal view {
        TaikoData.Block memory blk = L1.getBlock(blockId);
        printBlock(blk);

        for (uint32 i = 1; i < blk.nextTransitionId; ++i) {
            printTran(i, L1.getTransition(blockId, i));
        }
    }

    function printBlock(TaikoData.Block memory blk) internal view {
        TaikoData.SlotB memory b = L1.slotB();
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

    function printTran(uint64 tid, TaikoData.TransitionState memory ts) internal pure {
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

    function mineAndWrap(uint256 value) internal {
        vm.warp(block.timestamp + value);
    }
}
