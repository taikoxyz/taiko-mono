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
    DevnetInbox internal inbox;
    TaikoToken internal bondToken;

    address internal routerOwner;
    address internal whitelistOwner;
    address internal fallbackPreconfer;

    function setUpOnEthereum() internal virtual override {
        routerOwner = Alice;
        whitelistOwner = Alice;
        fallbackPreconfer = Frank;

        vm.chainId(1);

        // Step 1: Deploy supporting contracts
        bondToken = deployBondToken();
        SignalService signalService =
            deploySignalService(address(new SignalService(address(resolver))));
        address verifierAddr = address(new Verifier_ToggleStub());
        resolver.registerAddress(block.chainid, "proof_verifier", verifierAddr);

        // Step 2: Deploy DevnetInbox with wrapper=address(0) initially
        address inboxImpl = address(
            new DevnetInbox(
                LibNetwork.TAIKO_DEVNET,
                0, // cooldownWindow
                address(0), // wrapper - set to 0 initially
                verifierAddr,
                address(bondToken),
                address(signalService)
            )
        );

        address inboxProxy = deploy({
            name: "taiko",
            impl: inboxImpl,
            data: abi.encodeCall(TaikoInbox.v4Init, (address(0), bytes32(uint256(1))))
        });
        inbox = DevnetInbox(payable(inboxProxy));
        signalService.authorize(address(inbox), true);

        // Step 3: Deploy ForcedInclusionStore with placeholder TaikoWrapper
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

        // Step 4: Deploy PreconfWhitelist
        whitelist = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner, 2, 2))
            })
        );

        // Step 5: Deploy PreconfRouter (pointing to TaikoWrapper which we'll deploy next)
        // We need to know the TaikoWrapper address beforehand for the router
        // So we'll create router after TaikoWrapper

        // Step 6: Deploy TaikoWrapper with real ForcedInclusionStore
        taikoWrapper = TaikoWrapper(
            deploy({
                name: "taiko_wrapper",
                impl: address(
                    new TaikoWrapper(address(inbox), address(forcedInclusionStore), address(0))
                ),
                data: abi.encodeCall(TaikoWrapper.init, (address(0)))
            })
        );

        // Step 7: Upgrade ForcedInclusionStore with real TaikoWrapper address
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

        // Step 8: Deploy PreconfRouter pointing to TaikoWrapper
        router = PreconfRouter(
            deploy({
                name: "preconf_router",
                impl: address(
                    new PreconfRouter(address(taikoWrapper), address(whitelist), fallbackPreconfer)
                ),
                data: abi.encodeCall(PreconfRouter.init, (routerOwner))
            })
        );

        // Step 9: Update TaikoWrapper to know about the router
        UUPSUpgradeable(address(taikoWrapper)).upgradeTo(
            address(
                new TaikoWrapper(address(inbox), address(forcedInclusionStore), address(router))
            )
        );

        // Step 10: Configure inbox to only accept calls from TaikoWrapper
        // Upgrade inbox to set the wrapper
        UUPSUpgradeable(address(inbox)).upgradeTo(
            address(
                new DevnetInbox(
                    LibNetwork.TAIKO_DEVNET,
                    0, // cooldownWindow
                    address(taikoWrapper), // wrapper - now set to TaikoWrapper
                    verifierAddr,
                    address(bondToken),
                    address(signalService)
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
}
