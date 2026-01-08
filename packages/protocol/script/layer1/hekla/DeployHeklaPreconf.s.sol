// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";
import "src/layer1/forced-inclusion/TaikoWrapper.sol";
import "src/layer1/hekla/HeklaInbox.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";
import {DevnetInbox} from "../../../contracts/layer1/devnet/DevnetInbox.sol";

contract DeployHeklaPreconf is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address rollupResolver = 0x058810c7e843cbe7F94fF2edCa1941E226e3DF72;
        address taikoInbox = 0xeAd9c57ce675464AD9E7F60432DA65b84323a3A2;
        address fallbackPreconfProposer = 0x32C6404F14cafC89363801a8efEb697410a7F516;
        address proofVerifier = 0x10F65D0803d449617cdCFfc7C0Ce37119DBB6E8b;
        address taikoToken = 0xB3c5453C1c77D0d68487E9d34eeEC85fE13EEeeb;
        address signalService = 0xE4154D229b8185AF0604D06522dF1107395A13E9;
        address oldFork = 0x0883396A11a8c94Da64c39Eb3E61A2BCCccD2e1a;
        address whitelist=0x82792d9106b247a94D8a2591D515C1900c405b98;
        address taikoWrapper=0x0345678C1d0203BeF9b3B3f854a7800b2177772C;

//        address store = deployProxy({
//            name: "forced_inclusion_store",
//            impl: address(
//                new ForcedInclusionStore(
//                    uint8(vm.envUint("INCLUSION_WINDOW")),
//                    uint64(vm.envUint("INCLUSION_FEE_IN_GWEI")),
//                    taikoInbox,
//                    address(1)
//                )
//            ),
//            data: abi.encodeCall(ForcedInclusionStore.init, (address(0))),
//            registerTo: rollupResolver
//        });
//        address taikoWrapper = deployProxy({
//            name: "taiko_wrapper",
//            impl: address(new TaikoWrapper(taikoInbox, store, address(0))),
//            data: abi.encodeCall(TaikoWrapper.init, (msg.sender)),
//            registerTo: rollupResolver
//        });
//
//                address router = deployProxy({
//                    name: "preconf_router",
//                    impl: address(
//                        new PreconfRouter(
//                            taikoWrapper, whitelist, fallbackPreconfProposer, 0
//                        )
//                    ),
//                    data: abi.encodeCall(PreconfRouter.init, (address(0))),
//                    registerTo: rollupResolver
//                });
//
//        UUPSUpgradeable(taikoWrapper).upgradeTo(
//        address(new TaikoWrapper(taikoInbox, store, router))
//        );
//
//        UUPSUpgradeable(store).upgradeTo(
//            address(
//                new ForcedInclusionStore(
//                    uint8(vm.envUint("INCLUSION_WINDOW")),
//                    uint64(vm.envUint("INCLUSION_FEE_IN_GWEI")),
//                    taikoInbox,
//                    taikoWrapper
//                )
//            )
//        );
        address newFork =
            address(new DevnetInbox(167011,2 hours,taikoWrapper, proofVerifier, taikoToken, signalService));
//        address newRouter = address(new PacayaForkRouter(oldFork, newFork));
        UUPSUpgradeable(taikoInbox).upgradeTo(newFork);
//        TaikoInbox(taikoInbox).init(0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190, 0xeef96dc254e1ac4a0044b116e38b16dface1a153d9299c056552898a43f8513e);
    }
}
