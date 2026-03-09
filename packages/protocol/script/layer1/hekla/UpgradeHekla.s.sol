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

contract UpgradeHekla is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address taikoWrapper = 0xf90baFa5FCaC7645702EF912a5fd61828f5F71ba;
        address taikoInbox = 0x07700C3bC1B0EE3D311E7D642d364242fd537906;
        address proofVerifier = 0x2938b19a0F58717eA35dD337b05E21fa9Bf447E5;
        address taikoToken = 0xE6F90f363274d9Ea157EBe275A7669f6BA1Ec597;
        address signalService = 0xa02fB62CF77196D113c2EbC5D6e5316d7D1A7d63;

//        UUPSUpgradeable(taikoWrapper).upgradeTo(
//            address(new TaikoWrapper(taikoInbox, store, preconfRouter))
//        );
//        UUPSUpgradeable(preconfRouter).upgradeTo(
//            address(
//                new PreconfRouter(
//                    taikoWrapper, preconfWhitelist, fallbackPreconfProposer, type(uint64).max
//                )
//            )
//        );
//        UUPSUpgradeable(preconfWhitelist).upgradeTo(address(new PreconfWhitelist()));

        address newFork =
            address(new DevnetInbox(167014, 2 hours, taikoWrapper, proofVerifier, taikoToken, signalService));
//        address newRouter = address(new PacayaForkRouter(oldFork, newFork));
        UUPSUpgradeable(taikoInbox).upgradeTo(newFork);
    }
}
