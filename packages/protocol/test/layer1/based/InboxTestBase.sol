// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "test/layer1/based/helpers/Verifier_ToggleStub.sol";

abstract contract InboxTestBase is Layer1Test {
    using LibProofType for LibProofType.ProofType;

    mapping(uint256 => bytes) private _batchMetadatas;
    mapping(uint256 => bytes) private _batchInfos;

    ITaikoInbox internal inbox;
    TaikoToken internal bondToken;
    SignalService internal signalService;
    // Surge: use the verifier instance
    Verifier_ToggleStub internal verifier;
    uint256 genesisBlockProposedAt;
    uint256 genesisBlockProposedIn;
    uint256 private __blocksPerBatch;

    function pacayaConfig() internal view virtual returns (ITaikoInbox.Config memory);

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

        __blocksPerBatch = 1;

        signalService = deploySignalService(address(new SignalService(address(resolver))));

        verifier = new Verifier_ToggleStub();
        // Surge: do not register the verifier address

        inbox = deployInbox(
            correctBlockhash(0),
            // Surge: add dao address
            address(1),
            address(verifier),
            address(bondToken),
            address(signalService),
            pacayaConfig()
        );

        signalService.authorize(address(inbox), true);

        mineOneBlockAndWrap(12 seconds);
    }

    modifier WhenEachBatchHasMultipleBlocks(uint256 _blocksPerBatch) {
        __blocksPerBatch = _blocksPerBatch;
        _;
    }

    modifier WhenLogAllBatchesAndTransitions() {
        _logAllBatchesAndTransitions();
        _;
    }

    modifier WhenMultipleBatchesAreProposedWithDefaultParameters(uint256 numBatchesToPropose) {
        _proposeBatchesWithDefaultParameters(numBatchesToPropose);
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

    function _saveMetadataAndInfo(
        ITaikoInbox.BatchMetadata memory _metadata,
        ITaikoInbox.BatchInfo memory _info
    )
        internal
    {
        _batchMetadatas[_metadata.batchId] = abi.encode(_metadata);
        _batchInfos[_metadata.batchId] = abi.encode(_info);
    }

    function _loadMetadataAndInfo(uint64 _batchId)
        internal
        view
        returns (ITaikoInbox.BatchMetadata memory meta_, ITaikoInbox.BatchInfo memory info_)
    {
        bytes memory data = _batchMetadatas[_batchId];
        if (data.length != 0) {
            meta_ = abi.decode(data, (ITaikoInbox.BatchMetadata));
        }

        data = _batchInfos[_batchId];
        if (data.length != 0) {
            info_ = abi.decode(data, (ITaikoInbox.BatchInfo));
        }
    }

    function _proposeBatchesWithDefaultParameters(uint256 numBatchesToPropose)
        internal
        returns (uint64[] memory batchIds)
    {
        return _proposeBatchesWithDefaultParameters(numBatchesToPropose, abi.encodePacked("txList"));
    }

    function _proposeBatchesWithDefaultParameters(
        uint256 numBatchesToPropose,
        bytes memory txList
    )
        internal
        returns (uint64[] memory batchIds)
    {
        ITaikoInbox.BatchParams memory batchParams;
        batchParams.blocks = new ITaikoInbox.BlockParams[](__blocksPerBatch);

        batchIds = new uint64[](numBatchesToPropose);

        for (uint256 i; i < numBatchesToPropose; ++i) {
            (ITaikoInbox.BatchInfo memory info, ITaikoInbox.BatchMetadata memory meta) =
                inbox.proposeBatch(abi.encode(batchParams), txList);
            _saveMetadataAndInfo(meta, info);
            batchIds[i] = meta.batchId;
        }
    }

    function _proveBatchesWithCorrectTransitions(uint64[] memory batchIds) internal {
        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](batchIds.length);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](batchIds.length);

        for (uint256 i; i < metas.length; ++i) {
            (metas[i],) = _loadMetadataAndInfo(batchIds[i]);
            transitions[i].parentHash = correctBlockhash(batchIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(batchIds[i]);
            transitions[i].stateRoot = correctStateRoot(batchIds[i]);
        }

        // Surge: use happy case proof type
        inbox.proveBatches(abi.encode(_sgxSp1ProofType(), metas, transitions), "proof");
    }

    // Surge: helper to prove using a specific proof type
    function _proveBatchesWithProofType(
        LibProofType.ProofType proofType,
        uint64[] memory batchIds
    )
        internal
    {
        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](batchIds.length);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](batchIds.length);

        for (uint256 i; i < metas.length; ++i) {
            (metas[i],) = _loadMetadataAndInfo(batchIds[i]);
            transitions[i].parentHash = correctBlockhash(batchIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(batchIds[i]);
            transitions[i].stateRoot = correctStateRoot(batchIds[i]);
        }

        verifier.setProofType(proofType);
        inbox.proveBatches(abi.encode(proofType, metas, transitions), "proof");
    }

    // Surge: helper to push a conflicting proof type to a transition
    function _pushConflictingTransition(
        LibProofType.ProofType proofType,
        uint64[] memory batchIds
    )
        internal
    {
        _pushConflictingTransition(proofType, batchIds, 0);
    }

    // Surge: helper to push a conflicting proof type to a transition
    function _pushConflictingTransition(
        LibProofType.ProofType proofType,
        uint64[] memory batchIds,
        uint8 salt
    )
        internal
    {
        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](batchIds.length);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](batchIds.length);

        for (uint256 i; i < metas.length; ++i) {
            (metas[i],) = _loadMetadataAndInfo(batchIds[i]);
            // Parent hash is correct
            transitions[i].parentHash = correctBlockhash(batchIds[i] - 1);
            transitions[i].blockHash = conflictingBlockHash(batchIds[i], salt);
            transitions[i].stateRoot = conflictingStateRoot(batchIds[i], salt);
        }

        verifier.setProofType(proofType);
        inbox.proveBatches(abi.encode(proofType, metas, transitions), "proof");
    }

    function _proveBatchesWithWrongTransitions(uint64[] memory batchIds) internal {
        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](batchIds.length);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](batchIds.length);

        for (uint256 i; i < metas.length; ++i) {
            (metas[i],) = _loadMetadataAndInfo(batchIds[i]);
            transitions[i].parentHash = randBytes32();
            transitions[i].blockHash = randBytes32();
            transitions[i].stateRoot = randBytes32();
        }

        // Surge: use happy case proof type
        inbox.proveBatches(abi.encode(_sgxSp1ProofType(), metas, transitions), "proof");
    }

    function _logAllBatchesAndTransitions() internal view {
        console2.log(unicode"|───────────────────────────────────────────────────────────────");
        ITaikoInbox.Stats1 memory stats1 = inbox.getStats1();
        console2.log("Stats1 - lastSyncedBatchId:", stats1.lastSyncedBatchId);
        console2.log("Stats1 - lastSyncedAt:", stats1.lastSyncedAt);

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        console2.log("Stats2 - numBatches:", stats2.numBatches);
        console2.log("Stats2 - lastVerifiedBatchId:", stats2.lastVerifiedBatchId);
        console2.log("Stats2 - paused:", stats2.paused);
        console2.log("Stats2 - lastProposedIn:", stats2.lastProposedIn);
        console2.log("Stats2 - lastUnpausedAt:", stats2.lastUnpausedAt);

        // console2.log("stats2.numBatches:", stats2.numBatches);
        // console2.log("getConfig().maxUnverifiedBatches:", getConfig().maxUnverifiedBatches);

        uint64 firstBatchId = stats2.numBatches > pacayaConfig().maxUnverifiedBatches
            ? stats2.numBatches - pacayaConfig().maxUnverifiedBatches
            : 0;

        for (uint64 i = firstBatchId; i < stats2.numBatches; ++i) {
            ITaikoInbox.Batch memory batch = inbox.getBatch(i);
            if (batch.batchId <= stats2.lastVerifiedBatchId) {
                console2.log(unicode"|─ ✔ batch#", batch.batchId);
            } else {
                console2.log(unicode"|─── batch#", batch.batchId);
            }
            console2.log(unicode"│    |── metahash:", Strings.toHexString(uint256(batch.metaHash)));
            console2.log(unicode"│    |── lastBlockTimestamp:", batch.lastBlockTimestamp);
            console2.log(unicode"│    |── lastBlockId:", batch.lastBlockId);
            console2.log(unicode"│    |── livenessBond:", batch.livenessBond);
            console2.log(unicode"│    |── anchorBlockId:", batch.anchorBlockId);
            console2.log(unicode"│    |── nextTransitionId:", batch.nextTransitionId);
            console2.log(unicode"│    |── verifiedTransitionId:", batch.verifiedTransitionId);

            for (uint24 j = 1; j < batch.nextTransitionId; ++j) {
                ITaikoInbox.TransitionState[] memory transitions =
                    inbox.getTransitionsById(batch.batchId, j);
                for (uint256 k = 0; k < transitions.length; ++k) {
                    ITaikoInbox.TransitionState memory ts = transitions[k];
                    console2.log(unicode"│    |── transition#", j, ", conflict#", k);
                    console2.log(
                        unicode"│    │    |── parentHash:",
                        Strings.toHexString(uint256(ts.parentHash))
                    );
                    console2.log(
                        unicode"│    │    |── blockHash:",
                        Strings.toHexString(uint256(ts.blockHash))
                    );
                    console2.log(
                        unicode"│    │    |── stateRoot:",
                        Strings.toHexString(uint256(ts.stateRoot))
                    );
                    console2.log(
                        unicode"│    │    |── proofType:",
                        LibProofType.ProofType.unwrap(ts.proofType)
                    );
                    console2.log(unicode"│    │    └── bondReceiver:", ts.bondReceiver);
                    console2.log(unicode"│    │    └── createdAt:", ts.createdAt);
                }
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

    // Surge: helper to get a conflicting blockhash without salt
    function conflictingBlockHash(uint256 blockId) internal pure returns (bytes32) {
        return conflictingBlockHash(blockId, 0);
    }

    // Surge: helper to get a conflicting state root without salt
    function conflictingStateRoot(uint256 blockId) internal pure returns (bytes32) {
        return conflictingStateRoot(blockId, 0);
    }

    // Surge: helper to get a conflicting blockhash with salt
    function conflictingBlockHash(uint256 blockId, uint8 salt) internal pure returns (bytes32) {
        return bytes32(0x3000000 + blockId + salt);
    }

    // Surge: helper to get a conflicting state root with salt
    function conflictingStateRoot(uint256 blockId, uint8 salt) internal pure returns (bytes32) {
        return bytes32(0x4000000 + blockId + salt);
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

    // Surge: Add proof type helpers
    function _sgxSp1ProofType() internal pure returns (LibProofType.ProofType) {
        return LibProofType.sgxReth().combine(LibProofType.sp1Reth());
    }
}
