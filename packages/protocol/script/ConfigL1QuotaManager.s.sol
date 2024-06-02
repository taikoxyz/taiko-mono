// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/bridge/QuotaManager.sol";

// forge script --rpc-url  https://rpc.mainnet.taiko.xyz script/ConfigL1QuotaManager.s.sol
contract ConfigL1QuotaManager is DeployCapability {
    function run() external view {
        // Config L2-to-L1 quota
        uint104 value = 400_000; // USD
        uint104 priceETH = 3775; // USD
        uint104 priceTKO = 5; // USD

        console2.log("0x91f67118DD47d502B1f0C354D0611997B022f29E");

        uint104 amount;
        bytes memory call;
        // ETH
        amount = value * 1 ether / priceETH;
        call = abi.encodeCall(QuotaManager.updateQuota, (address(0), amount));
        console.log("ETH", amount);
        console.logBytes(call);

        // WETH
        amount = value * 1 ether / priceETH;
        call = abi.encodeCall(
            QuotaManager.updateQuota, (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, amount)
        );
        console.log("WETH", amount);
        console.logBytes(call);

        // TKO
        amount = value * 1e18 / priceTKO;
        call = abi.encodeCall(
            QuotaManager.updateQuota, (0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800, amount)
        );
        console.log("TKO", amount);
        console.logBytes(call);

        // USDT
        amount = value * 1e6;
        call = abi.encodeCall(
            QuotaManager.updateQuota, (0xdAC17F958D2ee523a2206206994597C13D831ec7, amount)
        );
        console.log("USDT", amount);
        console.logBytes(call);

        // USDC
        call = abi.encodeCall(
            QuotaManager.updateQuota, (0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, amount)
        );
        console.log("USDC", amount);
        console.logBytes(call);
    }
}
