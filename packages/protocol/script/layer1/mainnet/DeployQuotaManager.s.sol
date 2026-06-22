// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";
import "src/shared/bridge/QuotaManager.sol";
import "src/shared/common/IResolver.sol";
import "src/shared/libs/LibNames.sol";

/// @title DeployQuotaManager
/// @notice Deploys the {QuotaManager} and registers it as "quota_manager" in the shared resolver.
/// @dev Run after the bridge and the ERC20 vault have been deployed and registered, since the
/// QuotaManager binds to their addresses via immutables.
/// @custom:security-contact security@taiko.xyz
contract DeployQuotaManager is BaseScript {
    address owner = vm.envOr("OWNER", msg.sender);
    address quotaManagerAddress = vm.envOr("QUOTA_MANAGER", address(0));

    function run() external broadcast {
        QuotaManager qm;
        if (quotaManagerAddress != address(0)) {
            qm = QuotaManager(quotaManagerAddress);
            require(qm.owner() == msg.sender, "quota manager not owned by this contract");
        } else {
            checkResolverOwnership();

            address bridge = IResolver(resolver).resolve(block.chainid, LibNames.B_BRIDGE, false);
            address erc20Vault =
                IResolver(resolver).resolve(block.chainid, LibNames.B_ERC20_VAULT, false);

            qm = QuotaManager(
                deploy({
                    name: LibNames.B_QUOTA_MANAGER,
                    impl: address(new QuotaManager(bridge, erc20Vault)),
                    data: abi.encodeCall(QuotaManager.init, (owner, 15 minutes))
                })
            );
        }

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
