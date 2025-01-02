// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "test/layer1/based/helpers/Verifier_ToggleStub.sol";

abstract contract InboxTestBase is Layer1Test {
    mapping(uint256 => ITaikoInbox.BlockMetadataV3) internal blockMetadatas;
    ITaikoInbox internal inbox;
    TaikoToken internal bondToken;
    SignalService internal signalService;
    uint256 genesisBlockProposedAt;
    uint256 genesisBlockProposedIn;

    function getConfig() internal view virtual returns (ITaikoInbox.ConfigV3 memory);

    modifier transactBy(address transactor) override {
        vm.deal(transactor, 100 ether);
        if (bondToken != TaikoToken(address(0))) {
            bondToken.transfer(transactor, 10_000 ether);
            vm.startPrank(transactor);
            bondToken.approve(address(inbox), type(uint256).max);
        } else {
            vm.startPrank(transactor);
        }

        _;
        vm.stopPrank();
    }

    function setUpOnEthereum() internal virtual override {
        genesisBlockProposedAt = block.timestamp;
        genesisBlockProposedIn = block.number;

        inbox = deployInbox(correctBlockhash(0), getConfig());

        signalService = deploySignalService(address(new SignalService()));
        signalService.authorize(address(inbox), true);

        resolver.registerAddress(
            block.chainid, "proof_verifier", address(new Verifier_ToggleStub())
        );

        mineOneBlockAndWrap(12 seconds);
    }

    modifier WhenLogAllBlocksAndTransitions() {
        _logAllBlocksAndTransitions();
        _;
    }

    modifier WhenMultipleBlocksAreProposedWithDefaultParameters(uint256 numBlocksToPropose) {
        _proposeBlocksWithDefaultParameters(numBlocksToPropose);
        _;
    }

    modifier WhenMultipleBlocksAreProvedWithWrongTransitions(
        uint64 startBlockId,
        uint64 endBlockId
    ) {
        _proveBlocksWithWrongTransitions(range(startBlockId, endBlockId));
        _;
    }

    modifier WhenMultipleBlocksAreProvedWithCorrectTransitions(
        uint64 startBlockId,
        uint64 endBlockId
    ) {
        _proveBlocksWithCorrectTransitions(range(startBlockId, endBlockId));
        _;
    }

    // internal helper functions -------------------------------------------------------------------

    function _proposeBlocksWithDefaultParameters(uint256 numBlocksToPropose)
        internal
        returns (uint64[] memory blockIds)
    {
        // Provide a default value for txList
        bytes memory defaultTxList = abi.encodePacked("txList");
        return _proposeBlocksWithDefaultParameters(numBlocksToPropose, defaultTxList);
    }

    function _proposeBlocksWithDefaultParameters(
        uint256 numBlocksToPropose,
        bytes memory txList
    )
        internal
        returns (uint64[] memory blockIds)
    {
        ITaikoInbox.BlockParamsV3[] memory blockParams =
            new ITaikoInbox.BlockParamsV3[](numBlocksToPropose);

        ITaikoInbox.BlockMetadataV3[] memory metas =
            inbox.proposeBlocksV3(address(0), address(0), blockParams, txList);

        // Initialize blockIds array
        blockIds = new uint64[](metas.length);
        for (uint256 i; i < metas.length; ++i) {
            blockMetadatas[metas[i].blockId] = metas[i];
            blockIds[i] = metas[i].blockId;
        }
    }

    function _proveBlocksWithCorrectTransitions(uint64[] memory blockIds) internal {
        ITaikoInbox.BlockMetadataV3[] memory metas =
            new ITaikoInbox.BlockMetadataV3[](blockIds.length);
        ITaikoInbox.TransitionV3[] memory transitions =
            new ITaikoInbox.TransitionV3[](blockIds.length);

        for (uint256 i; i < metas.length; ++i) {
            metas[i] = blockMetadatas[blockIds[i]];
            transitions[i].parentHash = correctBlockhash(blockIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(blockIds[i]);
            transitions[i].stateRoot = correctStateRoot(blockIds[i]);
        }

        inbox.proveBlocksV3(metas, transitions, "proof");
    }

    function _proveBlocksWithWrongTransitions(uint64[] memory blockIds) internal {
        ITaikoInbox.BlockMetadataV3[] memory metas =
            new ITaikoInbox.BlockMetadataV3[](blockIds.length);
        ITaikoInbox.TransitionV3[] memory transitions =
            new ITaikoInbox.TransitionV3[](blockIds.length);

        for (uint256 i; i < metas.length; ++i) {
            metas[i] = blockMetadatas[blockIds[i]];
            transitions[i].parentHash = randBytes32();
            transitions[i].blockHash = randBytes32();
            transitions[i].stateRoot = randBytes32();
        }

        inbox.proveBlocksV3(metas, transitions, "proof");
    }

    function _logAllBlocksAndTransitions() internal view {
        console2.log(unicode"|───────────────────────────────────────────────────────────────");
        ITaikoInbox.Stats1 memory stats1 = inbox.getStats1();
        console2.log("Stats1 - lastSyncedBlockId:", stats1.lastSyncedBlockId);
        console2.log("Stats1 - lastSyncedAt:", stats1.lastSyncedAt);

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        console2.log("Stats2 - numBlocks:", stats2.numBlocks);
        console2.log("Stats2 - lastVerifiedBlockId:", stats2.lastVerifiedBlockId);
        console2.log("Stats2 - paused:", stats2.paused);
        console2.log("Stats2 - lastProposedIn:", stats2.lastProposedIn);
        console2.log("Stats2 - lastUnpausedAt:", stats2.lastUnpausedAt);

        // console2.log("stats2.numBlocks:", stats2.numBlocks);
        // console2.log("getConfig().blockRingBufferSize:", getConfig().blockRingBufferSize);

        uint64 firstBlockId = stats2.numBlocks > getConfig().blockRingBufferSize
            ? stats2.numBlocks - getConfig().blockRingBufferSize
            : 0;

        for (uint64 i = firstBlockId; i < stats2.numBlocks; ++i) {
            ITaikoInbox.BlockV3 memory blk = inbox.getBlockV3(i);
            if (blk.blockId <= stats2.lastVerifiedBlockId) {
                console2.log(unicode"|─ ✔ block#", blk.blockId);
            } else {
                console2.log(unicode"|─── block#", blk.blockId);
            }
            console2.log(unicode"│    |── metahash:", Strings.toHexString(uint256(blk.metaHash)));
            console2.log(unicode"│    |── timestamp:", blk.timestamp);
            console2.log(unicode"│    |── anchorBlockId:", blk.anchorBlockId);
            console2.log(unicode"│    |── nextTransitionId:", blk.nextTransitionId);
            console2.log(unicode"│    |── verifiedTransitionId:", blk.verifiedTransitionId);

            for (uint24 j = 1; j < blk.nextTransitionId; ++j) {
                ITaikoInbox.TransitionV3 memory tran = inbox.getTransitionV3(blk.blockId, j);
                console2.log(unicode"│    |── transition#", j);
                console2.log(
                    unicode"│    │    |── parentHash:",
                    Strings.toHexString(uint256(tran.parentHash))
                );
                console2.log(
                    unicode"│    │    |── blockHash:",
                    Strings.toHexString(uint256(tran.blockHash))
                );
                console2.log(
                    unicode"│    │    └── stateRoot:",
                    Strings.toHexString(uint256(tran.stateRoot))
                );
            }
        }
        console2.log("");
    }

    function correctBlockhash(uint256 blockId) internal pure returns (bytes32) {
        return bytes32(0x1000000 + blockId);
    }

    function correctStateRoot(uint256 blockId) internal pure returns (bytes32) {
        return bytes32(0x2000000 + blockId);
    }

    function range(uint64 start, uint64 end) internal pure returns (uint64[] memory arr) {
        arr = new uint64[](end - start);
        for (uint64 i; i < arr.length; ++i) {
            arr[i] = start + i;
        }
    }

    function mintEther(address to, uint256 amountEth) internal {
        vm.deal(to, amountEth);
        console2.log("Ether balance:", to, to.balance);
    }

    function mintTaikoToken(address to, uint256 amountTko) internal {
        bondToken.transfer(to, amountTko);

        vm.prank(to);
        bondToken.approve(address(inbox), amountTko);

        console2.log("Bond balance :", to, bondToken.balanceOf(to));
    }

    function setupBondTokenState(
        address user,
        uint256 initialBondBalance,
        uint256 bondAmount
    )
        internal
    {
        vm.deal(user, 1000 ether);
        bondToken.transfer(user, initialBondBalance);

        vm.prank(user);
        bondToken.approve(address(inbox), bondAmount);

        vm.prank(user);
        inbox.depositBond(bondAmount);
    }

    function simulateBlockDelay(uint256 secondsPerBlock, uint256 blocksToWait) internal {
        uint256 targetBlock = block.number + blocksToWait;
        uint256 targetTime = block.timestamp + (blocksToWait * secondsPerBlock);

        vm.roll(targetBlock);
        vm.warp(targetTime);
    }
}
