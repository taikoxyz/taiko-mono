// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../based/InboxTestBase.sol";
import "test/layer1/based/helpers/Verifier_ToggleStub.sol";
import "src/layer1/forced-inclusion/ForcedInclusionInbox.sol";
import "src/layer1/forced-inclusion/ForcedInclusionStore.sol";

contract ForcedInclusionInboxTest is InboxTestBase {
    function pacayaConfig() internal pure override returns (ITaikoInbox.Config memory) {
        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 15,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 125e18, // 125 Taiko token per batch
            livenessBondPerBlock: 5e18, // 5 Taiko token per block
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
            maxBlocksPerBatch: 768,
            forkHeights: ITaikoInbox.ForkHeights({ ontake: 0, pacaya: 0 })
        });
    }

    ForcedInclusionInbox internal forcedInclusionInbox;
    IForcedInclusionStore internal forcedInclusionStore;
    address owner;

    function setUpOnEthereum() internal virtual override {
        owner = Alice;

        genesisBlockProposedAt = block.timestamp;
        genesisBlockProposedIn = block.number;

        inbox = deployInbox(correctBlockhash(0), pacayaConfig());

        forcedInclusionStore = deployForcedInclusionStore(100, 100, owner);
        forcedInclusionInbox = deployForcedInclusionInbox();

        signalService = deploySignalService(address(new SignalService(address(resolver))));
        signalService.authorize(address(inbox), true);

        resolver.registerAddress(
            block.chainid, "proof_verifier", address(new Verifier_ToggleStub())
        );

        mineOneBlockAndWrap(12 seconds);
    }
}
