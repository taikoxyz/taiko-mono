// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";
import "src/layer1/forced-inclusion/TaikoWrapper.sol";
import "src/layer1/hekla/HeklaInbox.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";
import { DevnetInbox } from "../../../contracts/layer1/devnet/DevnetInbox.sol";

contract UpgradeHekla is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address taikoWrapper = 0x51273f9117eCeAFBaC891A880587fBe859654aCe;
        address taikoInbox = 0x079fd827004C7c06617EB32d5a55CC3e6d85e8DD;
        address proofVerifier = 0x9AaBba3Ae6D4aC3F5487608Da81006454e7933d3;
        address taikoToken = 0xE6F90f363274d9Ea157EBe275A7669f6BA1Ec597;
        address signalService = 0xAfaC833a3Ba21cbEE2C52023c7Fa0dc3FaC7F2e1;

        //        UUPSUpgradeable(taikoWrapper).upgradeTo(
        //            address(new TaikoWrapper(taikoInbox, store, preconfRouter))
        //        );
        //        UUPSUpgradeable(preconfRouter).upgradeTo(
        //            address(
        //                new PreconfRouter(
        //                    taikoWrapper, preconfWhitelist, fallbackPreconfProposer,
        // type(uint64).max )
        //            )
        //        );
        //        UUPSUpgradeable(preconfWhitelist).upgradeTo(address(new PreconfWhitelist()));

        UUPSUpgradeable(proofVerifier)
            .upgradeTo({
                newImplementation: address(
                    new DevnetVerifier(
                        taikoInbox,
                        0x17d9Ae481d901DDC08728E0B25307dAea1f8DE9D,
                        address(0),
                        0xf92b97Ac8C1D8bfCFCB26CFb153a36aDb99471EF,
                        0xCF5CA135AC33D6Fc3CE7752e5c7449f6cE4d0925,
                        0xb179D4038DD6084c548EEf674DAC262F51264e5e
                    )
                )
            });

        address newFork = address(
            new DevnetInbox(
                167_014, 2 hours, taikoWrapper, proofVerifier, taikoToken, signalService
            )
        );
        //        address newRouter = address(new PacayaForkRouter(oldFork, newFork));
        UUPSUpgradeable(taikoInbox).upgradeTo(newFork);
    }
}
