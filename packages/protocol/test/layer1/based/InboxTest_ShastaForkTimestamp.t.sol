// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "src/shared/based/LibSharedData.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/libs/LibStrings.sol";
import "src/layer1/based/TaikoInbox.sol";

contract InboxTest_ShastaForkTimestamp is InboxTestBase {
    uint64 private _shastaForkTimestamp;

    function pacayaConfig() internal pure override returns (ITaikoInbox.Config memory) {
        ITaikoInbox.ForkHeights memory forkHeights;

        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 11,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 125e18, // 125 Taiko token per batch
            livenessBondPerBlock: 0, // deprecated
            stateRootSyncInternal: 1,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000,
                maxGasIssuancePerBlock: 600_000_000
            }),
            provingWindow: 1 hours,
            cooldownWindow: 1 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: forkHeights
        });
    }

    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();

        _shastaForkTimestamp = uint64(block.timestamp + 1 hours);
    }

    function test_inbox_verify_batches_skips_signal_service_sync_after_shasta_timestamp() external {
        vm.deal(Alice, 100 ether);
        bondToken.transfer(Alice, 10_000 ether);

        vm.startPrank(Alice);
        bondToken.approve(address(inbox), type(uint256).max);
        _proposeBatchesWithDefaultParameters(1);
        _proveBatchesWithCorrectTransitions(range(1, 2));
        vm.stopPrank();

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 0);

        address verifier = resolver.resolve(block.chainid, "proof_verifier", false);
        address upgradedImpl = address(
            new ConfigurableInbox(
                address(0),
                verifier,
                address(bondToken),
                address(signalService),
                _shastaForkTimestamp
            )
        );

        vm.startPrank(Ownable2StepUpgradeable(address(inbox)).owner());
        UUPSUpgradeable(address(inbox)).upgradeTo(upgradedImpl);
        vm.stopPrank();

        vm.prank(signalService.owner());
        signalService.authorize(address(inbox), false);

        vm.warp(_shastaForkTimestamp + pacayaConfig().cooldownWindow + 1);
        TaikoInbox(address(inbox)).verifyBatches(1);

        stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);

        ITaikoInbox.Stats1 memory stats1 = inbox.getStats1();
        assertEq(stats1.lastSyncedBatchId, 1);

        assertFalse(
            signalService.isChainDataSynced(
                pacayaConfig().chainId, LibStrings.H_STATE_ROOT, 1, correctStateRoot(1)
            )
        );
    }
}
