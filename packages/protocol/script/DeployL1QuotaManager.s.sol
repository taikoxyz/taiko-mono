// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/bridge/QuotaManager.sol";

contract DeployL1QuotaManager is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    // MAINNET_SECURITY_COUNCIL: council.taiko.eth (0x7C50d60743D3FCe5a39FdbF687AFbAe5acFF49Fd)
    address public addressManager = vm.envAddress("L1_ROLLUP_ADDRESS_MANAGER");
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
        uint104 multiplier = 1; // we just change this one later

        uint104 value = 200_000 * multiplier; // USD
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
