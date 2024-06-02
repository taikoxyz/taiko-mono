// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/bridge/QuotaManager.sol";

// forge script  script/ConfigL1QuotaManager.s.sol
contract ConfigL1QuotaManager is DeployCapability {
    function run() external view {
        // Config L2-to-L1 quota
        uint104 value = 400_000; // USD
        uint104 priceETH = 3775; // USD
        uint104 priceTKO = 5; // USD

        console2.log("0x91f67118DD47d502B1f0C354D0611997B022f29E");

        // ETH and WETH
        console.log("ETH", address(0), value * 1 ether / priceETH);
        console.log("WETH", 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, value * 1 ether / priceETH);

        // TKO
        console.log("TKO", 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800, value * 1e18 / priceTKO);

        // USDT and USDC
        console.log("USDT", 0xdAC17F958D2ee523a2206206994597C13D831ec7, value * 1e6);
        console.log("USDC", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, value * 1e6);
    }
}
