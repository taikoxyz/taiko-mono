// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "test/layer1/based/helpers/Verifier_ToggleStub.sol";

abstract contract InboxTestBase is Layer1Test {
    uint256 constant PROVER_PRIVATE_KEY = 0x12345678;

    mapping(uint256 => bytes) private _batchMetadatas;
    mapping(uint256 => bytes) private _batchInfos;

    ITaikoInbox internal inbox;
    TaikoToken internal bondToken;
    SignalService internal signalService;
    uint256 genesisBlockProposedAt;
    uint256 genesisBlockProposedIn;
    uint256 internal __blocksPerBatch;

    function v4GetConfig() internal pure virtual returns (ITaikoInbox.Config memory) {
        ITaikoInbox.ForkHeights memory forkHeights;

        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 15,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token per batch
            stateRootSyncInternal: 5,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000, // correspond to 0.008847185 gwei basefee
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            provingWindow: 1 hours,
            cooldownWindow: 0 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: forkHeights
        });
    }

    modifier transactBy(address transactor) override {
        vm.deal(transactor, 100 ether);
        if (bondToken != TaikoToken(address(0))) {
            require(bondToken.transfer(transactor, 10_000 ether), "Transfer failed");
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

        address verifierAddr = address(new Verifier_ToggleStub());
        resolver.registerAddress(block.chainid, "proof_verifier", verifierAddr);

        inbox = deployInbox(
            correctBlockhash(0),
            verifierAddr,
            address(bondToken),
            address(signalService),
            v4GetConfig()
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
                inbox.v4ProposeBatch(abi.encode(batchParams), txList, "");
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

        inbox.v4ProveBatches(abi.encode(metas, transitions), "proof");
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

        inbox.v4ProveBatches(abi.encode(metas, transitions), "proof");
    }

    function _proposeBatchesWithProverAuth(
        address proposer,
        uint256 numBatchesToPropose,
        address prover,
        uint256 proverKey,
        bytes memory txList
    )
        internal
        returns (uint64[] memory batchIds)
    {
        batchIds = new uint64[](numBatchesToPropose);

        for (uint256 i; i < numBatchesToPropose; ++i) {
            ITaikoInbox.BatchParams memory batchParams;
            batchParams.blocks = new ITaikoInbox.BlockParams[](__blocksPerBatch);

            // Save original proposer for hash calculation
            batchParams.proposer = proposer;

            // Create ProverAuth struct
            LibProverAuth.ProverAuth memory auth;
            auth.prover = prover;
            auth.feeToken = address(bondToken);
            auth.fee = 5 ether;
            auth.validUntil = uint64(block.timestamp + 1 hours);
            auth.batchId =
                i == 0 ? inbox.v4GetStats2().numBatches : inbox.v4GetStats2().numBatches + uint64(i);

            // Calculate txListHash
            bytes32 txListHash = keccak256(txList);

            // Get chain ID
            uint64 chainId = uint64(v4GetConfig().chainId);
            batchParams.coinbase = proposer;

            // Calculate the batch params hash with proposer = msg.sender
            bytes32 batchParamsHash = keccak256(abi.encode(batchParams));

            // Reset proposer to address(0) as expected by the contract
            batchParams.proposer = address(0);

            // Sign the digest
            auth.signature = _signDigest(
                keccak256(
                    abi.encode(
                        "PROVER_AUTHENTICATION",
                        chainId,
                        batchParamsHash,
                        txListHash,
                        _getAuthWithoutSignature(auth)
                    )
                ),
                proverKey
            );

            // Encode the auth for the batch params
            batchParams.proverAuth = abi.encode(auth);

            // Propose the batch
            vm.prank(proposer);
            (ITaikoInbox.BatchInfo memory info, ITaikoInbox.BatchMetadata memory meta) =
                inbox.v4ProposeBatch(abi.encode(batchParams), txList, "");

            _saveMetadataAndInfo(meta, info);
            batchIds[i] = meta.batchId;
        }
    }

    // Add these helper functions if not already present
    function _signDigest(
        bytes32 _digest,
        uint256 _privateKey
    )
        internal
        pure
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, _digest);
        return abi.encodePacked(r, s, v);
    }

    function _getAuthWithoutSignature(LibProverAuth.ProverAuth memory _auth)
        internal
        pure
        returns (LibProverAuth.ProverAuth memory)
    {
        LibProverAuth.ProverAuth memory authCopy = _auth;
        authCopy.signature = "";
        return authCopy;
    }

    function _logAllBatchesAndTransitions() internal view {
        console2.log(unicode"|───────────────────────────────────────────────────────────────");
        ITaikoInbox.Stats1 memory stats1 = inbox.v4GetStats1();
        console2.log("Stats1 - lastSyncedBatchId:", stats1.lastSyncedBatchId);
        console2.log("Stats1 - lastSyncedAt:", stats1.lastSyncedAt);

        ITaikoInbox.Stats2 memory stats2 = inbox.v4GetStats2();
        console2.log("Stats2 - numBatches:", stats2.numBatches);
        console2.log("Stats2 - lastVerifiedBatchId:", stats2.lastVerifiedBatchId);
        console2.log("Stats2 - paused:", stats2.paused);
        console2.log("Stats2 - lastProposedIn:", stats2.lastProposedIn);
        console2.log("Stats2 - lastUnpausedAt:", stats2.lastUnpausedAt);

        // console2.log("stats2.numBatches:", stats2.numBatches);
        // console2.log("getConfig().maxUnverifiedBatches:", getConfig().maxUnverifiedBatches);

        uint64 firstBatchId = stats2.numBatches > v4GetConfig().maxUnverifiedBatches
            ? stats2.numBatches - v4GetConfig().maxUnverifiedBatches
            : 0;

        for (uint64 i = firstBatchId; i < stats2.numBatches; ++i) {
            ITaikoInbox.Batch memory batch = inbox.v4GetBatch(i);
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
                ITaikoInbox.TransitionState memory ts = inbox.v4GetTransitionById(batch.batchId, j);
                console2.log(unicode"│    |── transition#", j);
                console2.log(
                    unicode"│    │    |── parentHash:",
                    Strings.toHexString(uint256(ts.parentHash))
                );
                console2.log(
                    unicode"│    │    |── blockHash:",
                    Strings.toHexString(uint256(ts.blockHash))
                );
                console2.log(
                    unicode"│    │    └── stateRoot:",
                    Strings.toHexString(uint256(ts.stateRoot))
                );
                console2.log(unicode"│    │    └── prover:", ts.prover);

                console2.log(
                    unicode"│    │    └── inProvingWindow:",
                    ts.inProvingWindow ? "Y" : "N"
                );
                console2.log(unicode"│    │    └── createdAt:", ts.createdAt);
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
        require(bondToken.transfer(to, amountTko), "Transfer failed");

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
        require(bondToken.transfer(user, initialBondBalance), "Transfer failed");

        vm.prank(user);
        bondToken.approve(address(inbox), bondAmount);

        vm.prank(user);
        inbox.v4DepositBond(bondAmount);
    }
}
