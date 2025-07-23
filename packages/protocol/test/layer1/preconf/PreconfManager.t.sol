// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
    address public lastFeeRecipient;

    function setDueInclusion(bool _hasDue) external {
        hasDueInclusion = _hasDue;
    }

    function setNextInclusion(ForcedInclusion memory _inclusion) external {
        nextInclusion = _inclusion;
    }

    function isOldestForcedInclusionDue() external view returns (bool) {
        return hasDueInclusion;
    }

    function getOldestForcedInclusion() external view returns (ForcedInclusion memory) {
        return nextInclusion;
    }

    function consumeOldestForcedInclusion(address _feeRecipient)
        external
        returns (ForcedInclusion memory)
    {
        lastFeeRecipient = _feeRecipient;
        return nextInclusion;
    }

    function getForcedInclusion(uint256) external view returns (ForcedInclusion memory) {
        return nextInclusion;
    }

    function getOldestForcedInclusionDeadline() external pure returns (uint256) {
        return 0;
    }

    function storeForcedInclusion(uint8) external payable { }
}

contract MockInbox is IInbox {
    IInbox.Summary public nextSummary;
    bytes32 public nextForcedInclusionBlobHash;

    bytes public lastPackedSummary;
    bytes public lastPackedBatches;
    bytes public lastPackedEvidence;
    bytes public lastPackedTransitionMetas;

    function setNextReturn(IInbox.Summary memory _summary, bytes32 _blobHash) external {
        nextSummary = _summary;
        nextForcedInclusionBlobHash = _blobHash;
    }

    function propose4(
        bytes calldata _packedSummary,
        bytes calldata _packedBatches,
        bytes calldata _packedEvidence,
        bytes calldata _packedTransitionMetas
    )
        external
        returns (IInbox.Summary memory, bytes32)
    {
        lastPackedSummary = _packedSummary;
        lastPackedBatches = _packedBatches;
        lastPackedEvidence = _packedEvidence;
        lastPackedTransitionMetas = _packedTransitionMetas;

        return (nextSummary, nextForcedInclusionBlobHash);
    }

    function prove4(bytes calldata, bytes calldata) external { }
}

contract PreconfManagerTest is Test {
    PreconfManager public manager;
    MockWhitelist public whitelist;
    MockForcedInclusionStore public forcedStore;
    MockInbox public inbox;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public fallbackPreconfer = makeAddr("fallbackPreconfer");

    bytes32 public constant TEST_BLOB_HASH = bytes32(uint256(0x1234));

    function setUp() public {
        whitelist = new MockWhitelist();
        forcedStore = new MockForcedInclusionStore();
        inbox = new MockInbox();

        manager = new PreconfManager(
            address(inbox), address(whitelist), address(forcedStore), fallbackPreconfer
        );
    }

    function test_authorizedPreconferCanPropose() public {
        whitelist.setOperator(alice);

        IInbox.Summary memory summary;
        summary.nextBatchId = 1;
        inbox.setNextReturn(summary, bytes32(0));

        vm.prank(alice);
        (IInbox.Summary memory returnedSummary, bytes32 blobHash) =
            manager.propose4(hex"00", hex"01", hex"02", hex"03");

        assertEq(returnedSummary.nextBatchId, 1);
        assertEq(blobHash, bytes32(0));
    }

    function test_fallbackPreconferCanProposeWhenNoWhitelisted() public {
        whitelist.setOperator(address(0)); // No whitelisted operator

        IInbox.Summary memory summary;
        summary.nextBatchId = 1;
        inbox.setNextReturn(summary, bytes32(0));

        vm.prank(fallbackPreconfer);
        (IInbox.Summary memory returnedSummary, bytes32 blobHash) =
            manager.propose4(hex"00", hex"01", hex"02", hex"03");

        assertEq(returnedSummary.nextBatchId, 1);
        assertEq(blobHash, bytes32(0));
    }

    function test_unauthorizedCannotPropose() public {
        whitelist.setOperator(alice);

        vm.prank(bob);
        vm.expectRevert(PreconfManager.NotPreconfer.selector);
        manager.propose4(hex"00", hex"01", hex"02", hex"03");
    }

    function test_forcedInclusionMustBeProcessedWhenDue() public {
        whitelist.setOperator(alice);

        // Set up forced inclusion
        IForcedInclusionStore.ForcedInclusion memory forcedInclusion;
        forcedInclusion.blobHash = TEST_BLOB_HASH;
        forcedInclusion.feeInGwei = 100;

        forcedStore.setDueInclusion(true);
        forcedStore.setNextInclusion(forcedInclusion);

        // Inbox returns the forced inclusion blob hash
        IInbox.Summary memory summary;
        summary.nextBatchId = 1;
        inbox.setNextReturn(summary, TEST_BLOB_HASH);

        vm.prank(alice);
        (IInbox.Summary memory returnedSummary, bytes32 blobHash) =
            manager.propose4(hex"00", hex"01", hex"02", hex"03");

        assertEq(returnedSummary.nextBatchId, 1);
        assertEq(blobHash, TEST_BLOB_HASH);
        assertEq(forcedStore.lastFeeRecipient(), alice);
    }

    function test_forcedInclusionFailsIfNotProcessed() public {
        whitelist.setOperator(alice);

        // Set up forced inclusion
        IForcedInclusionStore.ForcedInclusion memory forcedInclusion;
        forcedInclusion.blobHash = TEST_BLOB_HASH;

        forcedStore.setDueInclusion(true);
        forcedStore.setNextInclusion(forcedInclusion);

        // Inbox returns zero (no forced inclusion processed)
        IInbox.Summary memory summary;
        inbox.setNextReturn(summary, bytes32(0));

        vm.prank(alice);
        vm.expectRevert(PreconfManager.ForcedInclusionNotProcessed.selector);
        manager.propose4(hex"00", hex"01", hex"02", hex"03");
    }

    function test_forcedInclusionFailsIfWrongBlobHash() public {
        whitelist.setOperator(alice);

        // Set up forced inclusion
        IForcedInclusionStore.ForcedInclusion memory forcedInclusion;
        forcedInclusion.blobHash = TEST_BLOB_HASH;

        forcedStore.setDueInclusion(true);
        forcedStore.setNextInclusion(forcedInclusion);

        // Inbox returns different blob hash
        IInbox.Summary memory summary;
        inbox.setNextReturn(summary, bytes32(uint256(0x5678)));

        vm.prank(alice);
        vm.expectRevert(PreconfManager.ForcedInclusionNotProcessed.selector);
        manager.propose4(hex"00", hex"01", hex"02", hex"03");
    }

    function test_noForcedInclusionWhenNotDue() public {
        whitelist.setOperator(alice);

        forcedStore.setDueInclusion(false);

        // Inbox should return zero blob hash
        IInbox.Summary memory summary;
        summary.nextBatchId = 1;
        inbox.setNextReturn(summary, bytes32(0));

        vm.prank(alice);
        (IInbox.Summary memory returnedSummary, bytes32 blobHash) =
            manager.propose4(hex"00", hex"01", hex"02", hex"03");

        assertEq(returnedSummary.nextBatchId, 1);
        assertEq(blobHash, bytes32(0));
    }

    function test_eventEmittedOnForcedInclusionProcessed() public {
        whitelist.setOperator(alice);

        IForcedInclusionStore.ForcedInclusion memory forcedInclusion;
        forcedInclusion.blobHash = TEST_BLOB_HASH;
        forcedInclusion.feeInGwei = 100;

        forcedStore.setDueInclusion(true);
        forcedStore.setNextInclusion(forcedInclusion);

        IInbox.Summary memory summary;
        inbox.setNextReturn(summary, TEST_BLOB_HASH);

        vm.expectEmit(true, true, false, true);
        emit PreconfManager.ForcedInclusionProcessed(alice, TEST_BLOB_HASH, 100);

        vm.prank(alice);
        manager.propose4(hex"00", hex"01", hex"02", hex"03");
    }
}
