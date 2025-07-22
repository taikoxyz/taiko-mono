// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
import "forge-std/src/Test.sol";
import "src/layer1/preconf/impl/PreconfManager.sol";
import "src/layer1/preconf/iface/IPreconfWhitelist.sol";
import "src/layer1/forced-inclusion/IForcedInclusionStore.sol";
import "src/layer1/based2/IInbox.sol";
import "src/layer1/based2/libs/LibCodec.sol";

contract MockWhitelist is IPreconfWhitelist {
    address public operator;

    function setOperator(address _operator) external {
        operator = _operator;
    }

    function getOperatorForCurrentEpoch() external view returns (address) {
        return operator;
    }

    function getOperatorForNextEpoch() external view returns (address) {
        return operator;
    }

    function getPrevProposerForEpochNumber(uint256) external pure returns (address) {
        return address(0);
    }

    function init(address, uint8, uint8) external { }

    function addOperator(address) external { }

    function removeOperator(uint256) external { }

    function removeOperator(address) external { }
}

contract MockForcedInclusionStore is IForcedInclusionStore {
    bool public hasDueInclusion;
    ForcedInclusion public nextInclusion;

    function setDueInclusion(bool _hasDue) external {
        hasDueInclusion = _hasDue;
    }

    function setNextInclusion(ForcedInclusion memory _inclusion) external {
        nextInclusion = _inclusion;
    }

    function isOldestForcedInclusionDue() external view returns (bool) {
        return hasDueInclusion;
    }

    function consumeOldestForcedInclusion(address) external returns (ForcedInclusion memory) {
        require(hasDueInclusion, "No due inclusion");
        hasDueInclusion = false;
        return nextInclusion;
    }

    // Implement other required functions
    function getForcedInclusion(uint256) external pure returns (ForcedInclusion memory) {
        return ForcedInclusion(bytes32(0), 0, 0, 0, 0, 0);
    }

    function getOldestForcedInclusionDeadline() external pure returns (uint256) {
        return 0;
    }

    function storeForcedInclusion(uint8, uint32, uint32) external payable { }
    
    function getOldestForcedInclusion() external view returns (ForcedInclusion memory) {
        require(hasDueInclusion, "No due inclusion");
        return nextInclusion;
    }
}

contract MockInbox is IInbox {
    Summary public lastSummary;

    function propose4(
        bytes calldata,
        bytes calldata,
        bytes calldata,
        bytes calldata
    )
        external
        returns (Summary memory)
    {
        lastSummary.nextBatchId++;
        return lastSummary;
    }

    function prove4(bytes calldata, bytes calldata) external { }
}

contract PreconfManagerTest is Test {
    PreconfManager public manager;
    MockWhitelist public whitelist;
    MockForcedInclusionStore public forcedStore;
    MockInbox public inbox;

    address public alice = address(0x1);
    address public bob = address(0x2);

    function setUp() public {
        whitelist = new MockWhitelist();
        forcedStore = new MockForcedInclusionStore();
        inbox = new MockInbox();

        manager = new PreconfManager(
            address(inbox),
            address(whitelist),
            address(forcedStore),
            alice // fallback preconfer
        );

        manager.init(address(this));
    }

    function testProposeAsPreconfer() public {
        // Set alice as the current preconfer
        whitelist.setOperator(alice);

        // Create a batch
        IInbox.Batch memory batch;
        batch.proposer = alice;
        batch.lastBlockTimestamp = 1000;
        batch.blocks = new IInbox.Block[](1);
        batch.blocks[0] = IInbox.Block({
            numTransactions: 100,
            timeShift: 0,
            anchorBlockId: 0,
            numSignals: 0,
            hasAnchor: false
        });

        // Create parent metadata
        IInbox.BatchProposeMetadata memory parentMeta = IInbox.BatchProposeMetadata({
            lastBlockTimestamp: 900,
            lastBlockId: 10,
            lastAnchorBlockId: 5
        });

        // Pack parameters for propose4 interface
        bytes memory packedSummary = LibCodec.packSummary(_createTestSummary());
        bytes memory packedBatches = LibCodec.packBatches(_createBatchArray(batch));
        bytes memory packedEvidence = LibCodec.packBatchProposeMetadataEvidence(
            IInbox.BatchProposeMetadataEvidence({
                leftHash: bytes32(0),
                proveMetaHash: bytes32(0),
                proposeMeta: parentMeta
            })
        );
        bytes memory packedTransitionMetas = "";

        // Propose as alice
        vm.prank(alice);
        IInbox.Summary memory summary =
            manager.propose(packedSummary, packedBatches, packedEvidence, packedTransitionMetas);

        // Verify the proposal was successful
        assertEq(summary.nextBatchId, 1);
    }

    function testProposeWithForcedInclusion() public {
        // Set alice as the current preconfer
        whitelist.setOperator(alice);

        // Set up a forced inclusion
        forcedStore.setDueInclusion(true);
        IForcedInclusionStore.ForcedInclusion memory inclusion = IForcedInclusionStore
            .ForcedInclusion({
            blobHash: bytes32(uint256(1)),
            feeInGwei: 10,
            createdAtBatchId: 1,
            blobByteOffset: 0,
            blobByteSize: 1000,
            blobCreatedIn: 100
        });
        forcedStore.setNextInclusion(inclusion);

        // Create a normal batch
        IInbox.Batch memory batch;
        batch.proposer = alice;
        batch.lastBlockTimestamp = 1000;
        batch.blocks = new IInbox.Block[](1);

        // Create parent metadata
        IInbox.BatchProposeMetadata memory parentMeta = IInbox.BatchProposeMetadata({
            lastBlockTimestamp: 900,
            lastBlockId: 10,
            lastAnchorBlockId: 5
        });

        // Pack parameters for propose4 interface
        bytes memory packedSummary = LibCodec.packSummary(_createTestSummary());
        bytes memory packedBatches = LibCodec.packBatches(_createBatchArray(batch));
        bytes memory packedEvidence = LibCodec.packBatchProposeMetadataEvidence(
            IInbox.BatchProposeMetadataEvidence({
                leftHash: bytes32(0),
                proveMetaHash: bytes32(0),
                proposeMeta: parentMeta
            })
        );
        bytes memory packedTransitionMetas = "";

        // Propose as alice - should process forced inclusion first
        vm.prank(alice);
        IInbox.Summary memory summary =
            manager.propose(packedSummary, packedBatches, packedEvidence, packedTransitionMetas);

        // Verify the proposal was successful
        assertEq(summary.nextBatchId, 1);

        // Verify forced inclusion was consumed
        assertFalse(forcedStore.hasDueInclusion());
    }

    function testProposeUnauthorized() public {
        // Don't set any operator

        // Create a batch
        IInbox.Batch memory batch;
        batch.proposer = bob;

        IInbox.BatchProposeMetadata memory parentMeta;

        // Pack parameters for propose4 interface
        bytes memory packedSummary = LibCodec.packSummary(_createTestSummary());
        bytes memory packedBatches = LibCodec.packBatches(_createBatchArray(batch));
        bytes memory packedEvidence = LibCodec.packBatchProposeMetadataEvidence(
            IInbox.BatchProposeMetadataEvidence({
                leftHash: bytes32(0),
                proveMetaHash: bytes32(0),
                proposeMeta: parentMeta
            })
        );
        bytes memory packedTransitionMetas = "";

        // Try to propose as bob (not authorized)
        vm.prank(bob);
        vm.expectRevert(PreconfManager.NotPreconfer.selector);
        manager.propose(packedSummary, packedBatches, packedEvidence, packedTransitionMetas);
    }

    function _createTestSummary() internal pure returns (IInbox.Summary memory) {
        return IInbox.Summary({
            nextBatchId: 1,
            lastSyncedBlockId: 0,
            lastSyncedAt: 0,
            lastVerifiedBatchId: 0,
            gasIssuanceUpdatedAt: 0,
            gasIssuancePerSecond: 0,
            lastVerifiedBlockHash: bytes32(0),
            lastBatchMetaHash: bytes32(0)
        });
    }

    function _createBatchArray(IInbox.Batch memory batch)
        internal
        pure
        returns (IInbox.Batch[] memory)
    {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);
        batches[0] = batch;
        return batches;
    }
}
*/
