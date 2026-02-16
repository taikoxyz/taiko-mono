// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SwapToken } from
    "../../../../contracts/layer1/surge/cross-chain-dex/SwapToken.sol";
import { CrossChainSwapVaultL1 } from
    "../../../../contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title DeployCrossChainDexL1
/// @notice Script to deploy the Cross-Chain DEX L1 contracts (vault-based)
/// @dev If SWAP_TOKEN env var is set, uses that existing token instead of deploying a new one.
contract DeployCrossChainDexL1 is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal immutable bridge = vm.envAddress("L1_BRIDGE");
    uint64 internal immutable l2ChainId = uint64(vm.envUint("L2_CHAIN_ID"));
    uint256 internal immutable initialTokenSupply = vm.envUint("INITIAL_TOKEN_SUPPLY");
    address internal immutable existingToken = vm.envOr("SWAP_TOKEN", address(0));

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run()
        external
        broadcast
        returns (address swapToken_, address l1Vault_)
    {
        address deployer = vm.addr(privateKey);

        console2.log("=====================================");
        console2.log("Deploying Cross-Chain DEX L1 (Vault)");
        console2.log("=====================================");
        console2.log("Deployer:", deployer);
        console2.log("Bridge:", bridge);
        console2.log("L2 Chain ID:", l2ChainId);
        console2.log("");

        if (existingToken != address(0)) {
            // Use existing token (e.g. real USDC on Gnosis)
            swapToken_ = existingToken;
            console2.log("Using existing token at:", swapToken_);
        } else {
            // Deploy SwapToken (canonical token on L1)
            SwapToken swapToken = new SwapToken("Swap Token", "SWAP", deployer, 0);
            swapToken_ = address(swapToken);
            console2.log("SwapToken deployed at:", swapToken_);

            // Mint initial supply to deployer
            swapToken.mint(deployer, initialTokenSupply);
            console2.log("Minted", initialTokenSupply, "tokens to deployer");
        }

        // Deploy L1 Vault
        CrossChainSwapVaultL1 l1Vault =
            new CrossChainSwapVaultL1(bridge, l2ChainId, swapToken_, deployer);
        l1Vault_ = address(l1Vault);
        console2.log("CrossChainSwapVaultL1 deployed at:", l1Vault_);

        // Write deployment addresses
        writeJson("SwapToken", swapToken_);
        writeJson("CrossChainSwapVaultL1", l1Vault_);

        console2.log("");
        console2.log("=====================================");
        console2.log("Deployment Complete");
        console2.log("=====================================");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Deploy L2 contracts using deploy_cross_chain_dex_l2.sh");
        console2.log("2. Set L2Vault on L1Vault (setup script)");
        console2.log("3. Set L1Vault on L2Vault (setup script)");
        console2.log("4. Add liquidity from L1 via addLiquidityToL2()");
    }

    function writeJson(string memory name, address addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/cross-chain-dex-l1.json")
        );
    }
}
