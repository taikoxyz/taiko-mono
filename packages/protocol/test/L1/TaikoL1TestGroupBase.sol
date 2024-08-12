// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestBase.sol";

contract TaikoL1New is TaikoL1 {
    function getConfig() public pure override returns (TaikoData.Config memory config) {
        config = TaikoL1.getConfig();
        config.maxBlocksToVerify = 0;
        config.blockMaxProposals = 20;
        config.blockRingBufferSize = 25;
        config.stateRootSyncInternal = 2;
    }
}

abstract contract TaikoL1TestGroupBase is TaikoL1TestBase {
    function deployTaikoL1() internal virtual override returns (TaikoL1) {
        return TaikoL1(
            payable(deployProxy({name: "taiko", impl: address(new TaikoL1New()), data: ""}))
        );
    }

    function proposeBlock(
        address proposer,
        bytes4 revertReason
    )
        internal
        returns (TaikoData.BlockMetadata memory meta)
    {
        TaikoData.HookCall[] memory hookcalls = new TaikoData.HookCall[](0);
        bytes memory txList = new bytes(10);

        vm.prank(proposer);
        if (revertReason != "") vm.expectRevert(revertReason);
        (meta,) = L1.proposeBlock{value: 3 ether}(
            abi.encode(TaikoData.BlockParams(address(0), address(0), 0, 0, hookcalls, "")), txList
        );
    }

    function proposeBlockV2(
        address proposer,
        TaikoData.BlockParamsV2 memory params,
        bytes4 revertReason
    )
        internal
        returns (TaikoData.BlockMetadataV2 memory)
    {
        bytes memory txList = new bytes(10);

        vm.prank(proposer);
        if (revertReason != "") vm.expectRevert(revertReason);
        return L1.proposeBlockV2(abi.encode(params), txList);
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

    function proveBlock2(
        address prover,
        TaikoData.BlockMetadataV2 memory meta,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 stateRoot,
        uint16 tier,
        bytes4 revertReason
    )
        internal
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
            gp.approveV2(meta, tran, proof);
            vm.prank(Emma, Emma);
            gp.approveV2(meta, tran, proof);

            if (revertReason != "") vm.expectRevert(revertReason);
            vm.prank(Frank);
            gp.approveV2(meta, tran, proof);
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

    function totalTkoBalance(
        TaikoToken tko,
        TaikoL1 L1,
        address user
    )
        internal
        view
        returns (uint256)
    {
        return tko.balanceOf(user) + L1.bondBalanceOf(user);
    }

    function printBlock(TaikoData.Block memory blk) internal view {
        (, TaikoData.SlotB memory b) = L1.getStateVariables();
        console2.log("\n==================");
        console2.log("---CHAIN:");
        console2.log(" | lastVerifiedBlockId:", b.lastVerifiedBlockId);
        console2.log(" | numBlocks:", b.numBlocks);
        console2.log(" | timestamp:", block.timestamp);
        console2.log("---BLOCK#", blk.blockId);
        console2.log(" | assignedProver:", blk.assignedProver);
        console2.log(" | livenessBond:", blk.livenessBond);
        console2.log(" | proposedAt:", blk.proposedAt);
        console2.log(" | proposedIn:", blk.proposedIn);
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
        console2.log("   | key (parentHash):", vm.toString(ts.key));
        console2.log("   | blockHash:", vm.toString(ts.blockHash));
        console2.log("   | stateRoot:", vm.toString(ts.stateRoot));
    }

    function mineAndWrap(uint256 value) internal {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + value);
    }
}
