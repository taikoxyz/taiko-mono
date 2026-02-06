// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";
import "src/layer1/forced-inclusion/TaikoWrapper.sol";
import "src/layer1/mainnet/MainnetInbox.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";

contract DeployMainnetPreconf is DeployCapability {
    uint8 public constant TWO_EPOCHS = 2;

    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address taikoWrapper = 0x9F9D2fC7abe74C79f86F0D1212107692430eef72;
        address rollupResolver = 0x5A982Fb1818c22744f5d7D36D0C4c9f61937b33a;
        address taikoInbox = 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
        address store = 0x05d88855361808fA1d7fc28084Ef3fCa191c4e03;
        address fallbackPreconfProposer = 0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9;
        address proofVerifier = 0xB16931e78d0cE3c9298bbEEf3b5e2276D34b8da1;
        address taikoToken = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
        address signalService = 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C;
        address oldFork = 0x904Da4C5bD76f932fE09fF32Ae5D7E3d2A5D2264;
        // admin.taiko.eth
        address contractOwner = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F;

        // Can't call `registerAddress` directly since the EOA isn't the owner of AddressResolver
        address whitelist = deployProxy({
            name: "preconf_whitelist",
            impl: address(new PreconfWhitelist()),
            data: abi.encodeCall(PreconfWhitelist.init, (contractOwner, TWO_EPOCHS, TWO_EPOCHS, uint256(vm.envUint("GENESIS_TIMESTAMP"))))
        });

        address router = deployProxy({
            name: "preconf_router",
            impl: address(
                new PreconfRouter(
                    taikoWrapper, whitelist, fallbackPreconfProposer, type(uint64).max
                )
            ),
            data: abi.encodeCall(PreconfRouter.init, (contractOwner))
        });
        address wrapper = address(new TaikoWrapper(taikoInbox, store, router));
        // Need to call `upgradeTo`, to address: 0x9F9D2fC7abe74C79f86F0D1212107692430eef72(should
        // be the final step after adding the operators and waiting for at least 2 epochs)
        console2.log("taikoWrapper: ", wrapper);
        address newFork =
            address(
                new MainnetInbox(
                    taikoWrapper,
                    proofVerifier,
                    taikoToken,
                    signalService,
                    uint64(vm.envOr("SHASTA_FORK_TIMESTAMP", uint256(type(uint64).max)))
                )
            );
        address newRouter = address(new PacayaForkRouter(oldFork, newFork));
        // Need to call `upgradeTo`, to address: 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a(should
        // be the final step after adding the operators and waiting for at least 2 epochs)
        console2.log("newRouter", newRouter);
    }
}
