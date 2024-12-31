// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";

contract InBoxTest_BlockParams is InboxTestBase {
    function getConfig() internal pure override returns (ITaikoInbox.ConfigV3 memory) {
        return ITaikoInbox.ConfigV3({
            chainId: LibNetwork.TAIKO_MAINNET,
            blockMaxProposals: 10,
            blockRingBufferSize: 15,
            maxBlocksToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
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
            maxSignalsToReceive: 16,
            forkHeights: ITaikoInbox.ForkHeights({ ontake: 0, pacaya: 0 })
        });
    }

    function setUpOnEthereum() internal override {
        super.setUpOnEthereum();
        bondToken = deployBondToken();
    }

    function test_validateBlockParams_defaults_when_anchorBlockId_is_zero()
        external
        transactBy(Alice)
    {
        ITaikoInbox.BlockParamsV3[] memory paramsArray = new ITaikoInbox.BlockParamsV3[](1);
        paramsArray[0] = ITaikoInbox.BlockParamsV3({
            anchorBlockId: 0, // Simulate missing anchor block ID
            timestamp: 0,
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            blobIndex: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0)
        });

        ITaikoInbox.BlockMetadataV3[] memory metas = inbox.proposeBlocksV3(
            address(0),
            address(0),
            paramsArray,
            "txList"
        );

        // Assert that the default anchorBlockId was set correctly
        uint64 expectedAnchorBlockId = uint64(block.number - 1);
        assertEq(metas[0].anchorBlockId, expectedAnchorBlockId, "AnchorBlockId mismatch");
    }

    function test_validateBlockParams_reverts_when_anchorBlockId_too_small()
        external
        transactBy(Alice)
    {
        ITaikoInbox.ConfigV3 memory config = inbox.getConfigV3();

        // Advance the block number to create the appropriate test scenario
        vm.roll(config.maxAnchorHeightOffset + 2);

        // Calculate an invalid anchorBlockId (too small)
        uint64 anchorBlockId = uint64(block.number - config.maxAnchorHeightOffset - 1);

        ITaikoInbox.BlockParamsV3[] memory paramsArray = new ITaikoInbox.BlockParamsV3[](1);
        paramsArray[0] = ITaikoInbox.BlockParamsV3({
            anchorBlockId: anchorBlockId,
            timestamp: 0,
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            blobIndex: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0)
        });

        vm.expectRevert(ITaikoInbox.AnchorBlockIdTooSmall.selector);
        inbox.proposeBlocksV3(
            address(0),
            address(0),
            paramsArray,
            "txList"
        );
    }

    function test_validateBlockParams_reverts_when_anchorBlockId_too_large()
        external
        transactBy(Alice)
    {
        // Calculate an invalid anchorBlockId (too large)
        uint64 anchorBlockId = uint64(block.number);

        ITaikoInbox.BlockParamsV3[] memory paramsArray = new ITaikoInbox.BlockParamsV3[](1);
        paramsArray[0] = ITaikoInbox.BlockParamsV3({
            anchorBlockId: anchorBlockId,
            timestamp: 0,
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            blobIndex: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0)
        });

        vm.expectRevert(ITaikoInbox.AnchorBlockIdTooLarge.selector);
        inbox.proposeBlocksV3(
            address(0),
            address(0),
            paramsArray,
            "txList"
        );
    }

    function test_validateBlockParams_reverts_when_anchorBlockId_smaller_than_parent()
        external
        transactBy(Alice)
    {
        vm.roll(10);
        _proposeBlocksWithDefaultParameters(1);
        ITaikoInbox.BlockV3 memory parent = inbox.getBlockV3(1);

        ITaikoInbox.BlockParamsV3[] memory paramsArray = new ITaikoInbox.BlockParamsV3[](1);
        paramsArray[0] = ITaikoInbox.BlockParamsV3({
            anchorBlockId: parent.anchorBlockId - 1,
            timestamp: 0,
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            blobIndex: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0)
        });

        vm.expectRevert(ITaikoInbox.AnchorBlockIdSmallerThanParent.selector);
        inbox.proposeBlocksV3(
            address(0),
            address(0),
            paramsArray,
            "txList"
        );
    }

    function test_validateBlockParams_when_anchorBlockId_is_not_zero()
        external
        transactBy(Alice)
    {
        ITaikoInbox.BlockParamsV3[] memory paramsArray = new ITaikoInbox.BlockParamsV3[](1);
        paramsArray[0] = ITaikoInbox.BlockParamsV3({
            anchorBlockId: uint64(block.number - 1),
            timestamp: 0,
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            blobIndex: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0)
        });

        ITaikoInbox.BlockMetadataV3[] memory metas = inbox.proposeBlocksV3(
            address(0),
            address(0),
            paramsArray,
            "txList"
        );

        uint64 expectedAnchorBlockId = uint64(block.number - 1);
        assertEq(metas[0].anchorBlockId, expectedAnchorBlockId, "AnchorBlockId mismatch");
    }

    function test_validateBlockParams_reverts_when_timestamp_too_large()
        external
        transactBy(Alice)
    {
        ITaikoInbox.BlockParamsV3[] memory paramsArray = new ITaikoInbox.BlockParamsV3[](1);
        paramsArray[0] = ITaikoInbox.BlockParamsV3({
            anchorBlockId: 0,
            timestamp: uint64(block.timestamp + 1),
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            blobIndex: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0)
        });

        vm.expectRevert(ITaikoInbox.TimestampTooLarge.selector);
        inbox.proposeBlocksV3(
            address(0),
            address(0),
            paramsArray,
            "txList"
        );
    }
}