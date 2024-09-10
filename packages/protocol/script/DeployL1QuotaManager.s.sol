// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/bridge/QuotaManager.sol";

contract DeployL1QuotaManager is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    // MAINNET_L1_SHARED_ADDRESS_MANAGER: 0xEf9EaA1dd30a9AA1df01c36411b5F082aA65fBaa
    address public addressManager = vm.envAddress("L1_SHARED_ADDRESS_MANAGER");
    // MAINNET_OWNER: admin.taiko.eth (0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F)
    address public owner = vm.envAddress("OWNER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Deploy the QuotaManager contract on Ethereum
        QuotaManager qm = QuotaManager(
            deployProxy({
                name: "quota_manager",
                impl: address(new QuotaManager()),
                data: abi.encodeCall(QuotaManager.init, (owner, addressManager, 15 minutes))
            })
        );

        // Config L2-to-L1 quota
        uint104 value = 200_000; // USD
        uint104 priceETH = 3100; // USD
        uint104 priceTKO = 5; // USD

        // ETH
        qm.updateQuota(address(0), value * 1 ether / priceETH);
        // WETH
        qm.updateQuota(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, value * 1 ether / priceETH);
        // TKO
        qm.updateQuota(0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800, value * 1e18 / priceTKO);
        // USDT
        qm.updateQuota(0xdAC17F958D2ee523a2206206994597C13D831ec7, value * 1e6);
        // USDC
        qm.updateQuota(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, value * 1e6);
    }
}
