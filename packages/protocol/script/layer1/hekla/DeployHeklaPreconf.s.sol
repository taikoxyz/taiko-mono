// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";
import "src/layer1/forced-inclusion/TaikoWrapper.sol";
import "src/layer1/hekla/HeklaInbox.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";

contract DeployHeklaPreconf is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address taikoWrapper = 0x8698690dEeDB923fA0A674D3f65896B0031BF7c9;
        address rollupResolver = 0x3C82907B5895DB9713A0BB874379eF8A37aA2A68;
        address taikoInbox = 0x79C9109b764609df928d16fC4a91e9081F7e87DB;
        address store = 0x54231533B8d8Ac2f4F9B05377B617EFA9be080Fd;
        address fallbackPreconfProposer = 0xD3f681bD6B49887A48cC9C9953720903967E9DC0;
        address proofVerifier = 0x9A919115127ed338C3bFBcdfBE72D4F167Fa9E1D;
        address taikoToken = 0x6490E12d480549D333499236fF2Ba6676C296011;
        address signalService = 0x6Fc2fe9D9dd0251ec5E0727e826Afbb0Db2CBe0D;
        address oldFork = 0x6e15d2049480C7E339C6B398774166e1ddbCd43e;

        //        address whitelist = deployProxy({
        //            name: "preconf_whitelist",
        //            impl: address(new PreconfWhitelist()),
        //            data: abi.encodeCall(PreconfWhitelist.init, (address(0), 2, 2)),
        //            registerTo: rollupResolver
        //        });
        //
        //        address router = deployProxy({
        //            name: "preconf_router",
        //            impl: address(
        //                new PreconfRouter(
        //                    taikoWrapper, whitelist, fallbackPreconfProposer, type(uint64).max
        //                )
        //            ),
        //            data: abi.encodeCall(PreconfRouter.init, (address(0))),
        //            registerTo: rollupResolver
        //        });
        //        address wrapper = address(new TaikoWrapper(taikoInbox, store, router));
        //        console2.log("taikoWrapper: ", wrapper);
        address newFork =
            address(new HeklaInbox(taikoWrapper, proofVerifier, taikoToken, signalService));
        address newRouter = address(new PacayaForkRouter(oldFork, newFork));
        UUPSUpgradeable(taikoInbox).upgradeTo(newRouter);
    }
}
