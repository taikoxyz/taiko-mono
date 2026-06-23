// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";
import "src/shared/bridge/QuotaManager.sol";
import "src/shared/common/IResolver.sol";
import "src/shared/libs/LibNames.sol";

/// @title DeployQuotaManager
/// @notice Deploys the non-upgradeable {QuotaManager} and configures the L2-to-L1 quota.
/// @dev Run after the bridge and ERC20 vault are deployed and registered in the shared resolver.
/// The deployer is set as the temporary owner so quotas can be configured, then ownership is handed
/// to OWNER via the 2-step flow (the new owner must call `acceptOwnership()`). The bridge and vault
/// must afterwards be upgraded with the deployed QuotaManager address to enable the checks.
/// @custom:security-contact security@taiko.xyz
contract DeployQuotaManager is BaseScript {
    function run() external broadcast {
        address newOwner = vm.envOr("OWNER", msg.sender);

        address bridge = IResolver(resolver).resolve(block.chainid, LibNames.B_BRIDGE, false);
        address erc20Vault =
            IResolver(resolver).resolve(block.chainid, LibNames.B_ERC20_VAULT, false);

        QuotaManager qm = new QuotaManager(msg.sender, bridge, erc20Vault, 15 minutes);
        console2.log("QuotaManager deployed:", address(qm));

        // Config L2-to-L1 quota
        uint104 value = 200_000; // USD
        uint104 priceETH = 1750; // USD
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

        if (newOwner != msg.sender) {
            qm.transferOwnership(newOwner);
            console2.log("Ownership transfer initiated to:", newOwner);
        }
    }
}
