// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "./TestTierRouter.sol";
import "./TestVerifier.sol";

abstract contract TaikoL1Test is Layer1Test {
    bytes32 internal GENESIS_BLOCK_HASH = keccak256("GENESIS_BLOCK_HASH");

    TaikoToken internal bondToken;
    SignalService internal signalService;
    Bridge internal bridge;
    ITierRouter internal tierRouter;
    TestVerifier internal tier1Verifier;
    TestVerifier internal tier2Verifier;
    TestVerifier internal tier3Verifier;
    TaikoL1 internal taikoL1;

    address internal tSignalService = randAddress();
    address internal taikoL2 = randAddress();

    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        signalService = deploySignalService(address(new SignalService()));
        bridge = deployBridge(address(new Bridge()));
        tierRouter = deployTierRouter();
        tier1Verifier = deployVerifier("");
        tier2Verifier = deployVerifier("tier_2");
        tier3Verifier = deployVerifier("tier_3");
        taikoL1 = deployTaikoL1(getConfig());

        signalService.authorize(address(taikoL1), true);
    }

    function setUpOnTaiko() internal override {
        register("taiko", taikoL2);
        register("signal_service", tSignalService);
    }

    function tierProvider() internal view returns (ITierProvider) {
        return ITierProvider(address(tierRouter));
    }

    // TODO: order and name mismatch
    function giveEthAndTko(address to, uint256 amountTko, uint256 amountEth) internal {
        vm.deal(to, amountEth);
        bondToken.transfer(to, amountTko);

        vm.prank(to);
        bondToken.approve(address(taikoL1), amountTko);

        console2.log("Bond balance :", to, bondToken.balanceOf(to));
        console2.log("Ether balance:", to, to.balance);
    }

    function proposeBlock(
        address proposer,
        bytes4 revertReason
    )
        internal
        returns (TaikoData.BlockMetadataV2 memory)
    {
        vm.prank(proposer);
        if (revertReason != "") vm.expectRevert(revertReason);
        return taikoL1.proposeBlockV2("", new bytes(10));
    }

    function proposeBlock(
        address proposer,
        TaikoData.BlockParamsV2 memory params,
        bytes4 revertReason
    )
        internal
        returns (TaikoData.BlockMetadataV2 memory)
    {
        vm.prank(proposer);
        if (revertReason != "") vm.expectRevert(revertReason);
        return taikoL1.proposeBlockV2(abi.encode(params), new bytes(10));
    }

    function proveBlock(
        address prover,
        TaikoData.BlockMetadataV2 memory meta,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 stateRoot,
        uint16 tierId,
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
        proof.tier = tierId;
        proof.data = "proofdata";

        if (revertReason != "") vm.expectRevert(revertReason);
        vm.prank(prover);
        taikoL1.proveBlock(meta.id, abi.encode(meta, tran, proof));
    }

    function getBondTokenBalance(address user) internal view returns (uint256) {
        return bondToken.balanceOf(user) + taikoL1.bondBalanceOf(user);
    }

    function printBlockAndTrans(uint64 blockId) internal view {
        TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(blockId);
        printBlock(blk);

        for (uint32 i = 1; i < blk.nextTransitionId; ++i) {
            printTran(i, taikoL1.getTransition(blockId, i));
        }
    }

    function printBlock(TaikoData.BlockV2 memory blk) internal view {
        (, TaikoData.SlotB memory b) = taikoL1.getStateVariables();
        console2.log("\n==================");
        console2.log("---CHAIN:");
        console2.log(" | lastVerifiedBlockId:", b.lastVerifiedBlockId);
        console2.log(" | numBlocks:", b.numBlocks);
        console2.log(" | timestamp:", block.timestamp);
        console2.log("---BLOCK#", blk.blockId);
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

    function deployTierRouter() internal returns (ITierRouter tierRouter) {
        tierRouter = new TestTierRouter();
        register("tier_router", address(tierRouter));
    }

    function deployTaikoL1(TaikoData.Config memory config) internal returns (TaikoL1) {
        return TaikoL1(
            deploy({
                name: "taiko",
                impl: address(new TaikoL1WithConfig()),
                data: abi.encodeCall(
                    TaikoL1WithConfig.initWithConfig,
                    (address(0), address(resolver), GENESIS_BLOCK_HASH, false, config)
                )
            })
        );
    }

    function deployVerifier(bytes32 name) internal returns (TestVerifier verifier) {
        verifier = new TestVerifier();
        register(name, address(verifier));
    }

    function getConfig() internal view virtual returns (TaikoData.Config memory);
}
