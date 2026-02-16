// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SwapTokenL2 } from
    "../../../../contracts/layer2/surge/cross-chain-dex/SwapTokenL2.sol";
import { SimpleDEX } from "../../../../contracts/layer2/surge/cross-chain-dex/SimpleDEX.sol";
import { CrossChainSwapVaultL2 } from
    "../../../../contracts/layer2/surge/cross-chain-dex/CrossChainSwapVaultL2.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title DeployCrossChainDexL2
/// @notice Script to deploy the Cross-Chain DEX L2 contracts (vault-based, no mock minting)
contract DeployCrossChainDexL2 is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal immutable bridge = vm.envAddress("L2_BRIDGE");
    uint64 internal immutable l1ChainId = uint64(vm.envUint("L1_CHAIN_ID"));

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run()
        external
        broadcast
        returns (address swapTokenL2_, address dex_, address l2Vault_)
    {
        address deployer = vm.addr(privateKey);

        console2.log("=====================================");
        console2.log("Deploying Cross-Chain DEX L2 (Vault)");
        console2.log("=====================================");
        console2.log("Deployer:", deployer);
        console2.log("Bridge:", bridge);
        console2.log("L1 Chain ID:", l1ChainId);
        console2.log("");

        // Deploy SwapTokenL2 (bridged token) with deployer as initial minter
        // 6 decimals to match canonical USDC on L1
        SwapTokenL2 swapTokenL2 =
            new SwapTokenL2("Bridged USDC", "bUSDC", deployer, 0, 6);
        swapTokenL2_ = address(swapTokenL2);
        console2.log("SwapTokenL2 deployed at:", swapTokenL2_);

        // Deploy SimpleDEX
        SimpleDEX dex = new SimpleDEX(swapTokenL2_, deployer);
        dex_ = address(dex);
        console2.log("SimpleDEX deployed at:", dex_);

        // Deploy L2 Vault
        CrossChainSwapVaultL2 l2Vault =
            new CrossChainSwapVaultL2(bridge, l1ChainId, dex_, swapTokenL2_, deployer);
        l2Vault_ = address(l2Vault);
        console2.log("CrossChainSwapVaultL2 deployed at:", l2Vault_);

        // Transfer minting authority to L2 vault
        swapTokenL2.setMinter(l2Vault_);
        console2.log("Transferred minting authority to L2Vault");

        // Set L2 vault as authorized liquidity provider on DEX
        dex.setLiquidityProvider(l2Vault_);
        console2.log("Set L2Vault as DEX liquidity provider");

        // NO mock minting! NO initial liquidity!
        // Liquidity will be added from L1 via addLiquidityToL2()

        // Write deployment addresses
        writeJson("SwapTokenL2", swapTokenL2_);
        writeJson("SimpleDEX", dex_);
        writeJson("CrossChainSwapVaultL2", l2Vault_);

        console2.log("");
        console2.log("=====================================");
        console2.log("Deployment Complete");
        console2.log("=====================================");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Set L2Vault on L1Vault (setup script on L1)");
        console2.log("2. Set L1Vault on L2Vault (setup script on L2)");
        console2.log("3. Add liquidity from L1 via addLiquidityToL2()");
    }

    function writeJson(string memory name, address addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/cross-chain-dex-l2.json")
        );
    }
}
