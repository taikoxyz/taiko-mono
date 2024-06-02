// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/bridge/QuotaManager.sol";

// forge script --rpc-url  https://rpc.mainnet.taiko.xyz script/ConfigL1QuotaManager.s.sol
contract ConfigL1QuotaManager is DeployCapability {
    function run() external view {
        // Config L2-to-L1 quota
        uint104 value = 500_000; // USD
        uint104 priceETH = 3775; // USD
        uint104 priceTKO = 5; // USD

        bytes memory call;
        // ETH
        call = abi.encodeCall(QuotaManager.updateQuota, (address(0), value * 1 ether / priceETH));
        console.logBytes(call);

        // WETH
        call = abi.encodeCall(
            QuotaManager.updateQuota,
            (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, value * 1 ether / priceETH)
        );
        console.logBytes(call);

        // TKO
        call = abi.encodeCall(
            QuotaManager.updateQuota,
            (0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800, value * 1e18 / priceTKO)
        );
        console.logBytes(call);

        // USDT
        call = abi.encodeCall(
            QuotaManager.updateQuota, (0xdAC17F958D2ee523a2206206994597C13D831ec7, value * 1e6)
        );
        console.logBytes(call);

        // USDC
        call = abi.encodeCall(
            QuotaManager.updateQuota, (0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, value * 1e6)
        );
        console.logBytes(call);
    }
}
