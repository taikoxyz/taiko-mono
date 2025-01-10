// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "test/layer1/based/helpers/Verifier_ToggleStub.sol";

abstract contract InboxTestBase is Layer1Test {
    mapping(uint256 => ITaikoInbox.BatchMetadata) internal batchMetadatas;
    ITaikoInbox internal inbox;
    TaikoToken internal bondToken;
    SignalService internal signalService;
    uint256 genesisBlockProposedAt;
    uint256 genesisBlockProposedIn;

    function getConfig() internal view virtual returns (ITaikoInbox.Config memory);

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

    modifier WhenMultipleBatchesAreProvedWithWrongTransitions(
        uint64 startBatchId,
        uint64 endBatchId
    ) {
        _proveBatchesWithWrongTransitions(range(startBatchId, endBatchId));
        _;
    }

    modifier WhenMultipleBatchesAreProvedWithCorrectTransitions(
        uint64 startBatchId,
        uint64 endBatchId
    ) {
        _proveBatchesWithCorrectTransitions(range(startBatchId, endBatchId));
        _;
    }

    // internal helper functions
    // -------------------------------------------------------------------

    function _proposeBlocksWithDefaultParameters(uint256 numBlocksToPropose)
        internal
        returns (uint64 batchId)
    {
        // Provide a default value for txList
        bytes memory defaultTxList = abi.encodePacked("txList");
        return _proposeBatchWithDefaultParameters(numBlocksToPropose, defaultTxList);
    }

    function _proposeBatchWithDefaultParameters(
        uint256 numBlocksToPropose,
        bytes memory txList
    )
        internal
        returns (uint64 batchId)
    {
        ITaikoInbox.BatchParams memory batchParams;

        ITaikoInbox.BatchMetadata memory meta =
            inbox.proposeBatch(address(0), address(0), batchParams, txList);

        return meta.batchId;
    }

    function _proveBatchesWithCorrectTransitions(uint64[] memory batchIds) internal {
        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](batchIds.length);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](batchIds.length);

        for (uint256 i; i < metas.length; ++i) {
            metas[i] = batchMetadatas[batchIds[i]];
            transitions[i].parentHash = correctBlockhash(batchIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(batchIds[i]);
            transitions[i].stateRoot = correctStateRoot(batchIds[i]);
        }

        inbox.proveBatches(metas, transitions, "proof");
    }

    function _proveBatchesWithWrongTransitions(uint64[] memory batchIds) internal {
        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](batchIds.length);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](batchIds.length);

        for (uint256 i; i < metas.length; ++i) {
            metas[i] = batchMetadatas[batchIds[i]];
            transitions[i].parentHash = randBytes32();
            transitions[i].blockHash = randBytes32();
            transitions[i].stateRoot = randBytes32();
        }

        inbox.proveBatches(metas, transitions, "proof");
    }

    function _logAllBlocksAndTransitions() internal view {
        console2.log(unicode"|───────────────────────────────────────────────────────────────");
        ITaikoInbox.Stats1 memory stats1 = inbox.getStats1();
        console2.log("Stats1 - lastSyncedBatch:", stats1.lastSyncedBatch);
        console2.log("Stats1 - lastSyncedAt:", stats1.lastSyncedAt);

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        console2.log("Stats2 - numBatches:", stats2.numBatches);
        console2.log("Stats2 - lastVerifiedBatch:", stats2.lastVerifiedBatch);
        console2.log("Stats2 - paused:", stats2.paused);
        console2.log("Stats2 - lastProposedIn:", stats2.lastProposedIn);
        console2.log("Stats2 - lastUnpausedAt:", stats2.lastUnpausedAt);

        // console2.log("stats2.numBlocks:", stats2.numBlocks);
        // console2.log("getConfig().blockRingBufferSize:", getConfig().blockRingBufferSize);

        uint64 firstBatchId = stats2.numBatches > getConfig().maxBatchProposals
            ? stats2.numBatches - getConfig().maxBatchProposals
            : 0;

        for (uint64 i = firstBatchId; i < stats2.numBatches; ++i) {
            ITaikoInbox.Batch memory batch = inbox.getBatch(i);
            if (batch.batchId <= stats2.lastVerifiedBatch) {
                console2.log(unicode"|─ ✔ batch#", batch.batchId);
            } else {
                console2.log(unicode"|─── batch#", batch.batchId);
            }
            console2.log(unicode"│    |── metahash:", Strings.toHexString(uint256(batch.metaHash)));
            console2.log(unicode"│    |── timestamp:", batch.timestamp);
            console2.log(unicode"│    |── anchorBlockId:", batch.anchorBlockId);
            console2.log(unicode"│    |── nextTransitionId:", batch.nextTransitionId);
            console2.log(unicode"│    |── verifiedTransitionId:", batch.verifiedTransitionId);

            for (uint24 j = 1; j < batch.nextTransitionId; ++j) {
                ITaikoInbox.Transition memory tran = inbox.getTransition(batch.batchId, j);
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
