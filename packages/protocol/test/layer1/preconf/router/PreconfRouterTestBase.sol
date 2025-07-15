// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../Layer1Test.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/devnet/DevnetInbox.sol";
import "src/layer1/forced-inclusion/TaikoWrapper.sol";
import "src/layer1/forced-inclusion/ForcedInclusionStore.sol";
import "src/shared/signal/SignalService.sol";
import "test/layer1/based/helpers/Verifier_ToggleStub.sol";
import "src/shared/libs/LibNetwork.sol";

abstract contract PreconfRouterTestBase is Layer1Test {
    PreconfRouter internal router;
    PreconfWhitelist internal whitelist;
    TaikoWrapper internal taikoWrapper;
    ForcedInclusionStore internal forcedInclusionStore;
    ITaikoInbox internal inbox;
    TaikoToken internal bondToken;

    address internal routerOwner;
    address internal whitelistOwner;
    address internal fallbackPreconfer;

    function setUpOnEthereum() internal virtual override {
        routerOwner = Alice;
        whitelistOwner = Alice;
        fallbackPreconfer = Frank;

        vm.chainId(1);

        // Deploy supporting contracts
        bondToken = deployBondToken();
        SignalService signalService =
            deploySignalService(address(new SignalService(address(resolver))));
        address verifierAddr = address(new Verifier_ToggleStub());
        resolver.registerAddress(block.chainid, "proof_verifier", verifierAddr);

        // Deploy Inbox with wrapper=address(0) initially
        inbox = deployInbox(
            correctBlockhash(0),
            verifierAddr,
            address(bondToken),
            address(signalService),
            address(0),
            v4GetConfig()
        );

        signalService.authorize(address(inbox), true);

        //  Deploy ForcedInclusionStore with placeholder TaikoWrapper
        forcedInclusionStore = ForcedInclusionStore(
            deploy({
                name: "forced_inclusion_store",
                impl: address(
                    new ForcedInclusionStore(
                        4, // inclusionWindow
                        1 gwei, // inclusionFeeInGwei
                        address(inbox),
                        address(1) // placeholder TaikoWrapper
                    )
                ),
                data: abi.encodeCall(ForcedInclusionStore.init, (address(0)))
            })
        );

        // Deploy PreconfWhitelist
        whitelist = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner, 2, 2))
            })
        );

        // Deploy TaikoWrapper with real ForcedInclusionStore
        taikoWrapper = TaikoWrapper(
            deploy({
                name: "taiko_wrapper",
                impl: address(
                    new TaikoWrapper(address(inbox), address(forcedInclusionStore), address(0))
                ),
                data: abi.encodeCall(TaikoWrapper.init, (address(0)))
            })
        );

        // Upgrade ForcedInclusionStore with real TaikoWrapper address
        UUPSUpgradeable(address(forcedInclusionStore)).upgradeTo(
            address(
                new ForcedInclusionStore(
                    4, // inclusionWindow
                    1 gwei, // inclusionFeeInGwei
                    address(inbox),
                    address(taikoWrapper) // real TaikoWrapper
                )
            )
        );

        // Deploy PreconfRouter pointing to TaikoWrapper
        router = PreconfRouter(
            deploy({
                name: "preconf_router",
                impl: address(
                    new PreconfRouter(address(taikoWrapper), address(whitelist), fallbackPreconfer)
                ),
                data: abi.encodeCall(PreconfRouter.init, (routerOwner))
            })
        );

        // Upgrade TaikoWrapper to know about the router
        UUPSUpgradeable(address(taikoWrapper)).upgradeTo(
            address(
                new TaikoWrapper(address(inbox), address(forcedInclusionStore), address(router))
            )
        );

        // Upgrade inbox to only accept calls from TaikoWrapper
        UUPSUpgradeable(address(inbox)).upgradeTo(
            address(
                new ConfigurableInbox(
                    address(taikoWrapper), verifierAddr, address(bondToken), address(signalService)
                )
            )
        );
    }

    function addOperators(address[] memory operators) internal {
        for (uint256 i = 0; i < operators.length; i++) {
            vm.prank(whitelistOwner);
            whitelist.addOperator(operators[i]);
        }
    }

    function correctBlockhash(uint256 blockId) internal pure returns (bytes32) {
        return bytes32(0x1000000 + blockId);
    }

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
}
