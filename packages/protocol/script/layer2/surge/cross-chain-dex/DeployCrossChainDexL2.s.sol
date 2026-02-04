// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SwapTokenL2 } from
    "../../../../contracts/layer2/surge/cross-chain-dex/SwapTokenL2.sol";
import { SimpleDEX } from "../../../../contracts/layer2/surge/cross-chain-dex/SimpleDEX.sol";
import { CrossChainSwapHandlerL2 } from
    "../../../../contracts/layer2/surge/cross-chain-dex/CrossChainSwapHandlerL2.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title DeployCrossChainDexL2
/// @notice Script to deploy the Cross-Chain DEX L2 contracts
contract DeployCrossChainDexL2 is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal immutable bridge = vm.envAddress("L2_BRIDGE");
    uint64 internal immutable l1ChainId = uint64(vm.envUint("L1_CHAIN_ID"));
    uint256 internal immutable initialLiquidityETH = vm.envUint("INITIAL_LIQUIDITY_ETH");
    uint256 internal immutable initialLiquidityToken = vm.envUint("INITIAL_LIQUIDITY_TOKEN");
    uint256 internal immutable handlerTokenReserve = vm.envUint("HANDLER_TOKEN_RESERVE");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run()
        external
        broadcast
        returns (address swapTokenL2_, address dex_, address l2Handler_)
    {
        address deployer = vm.addr(privateKey);

        console2.log("=====================================");
        console2.log("Deploying Cross-Chain DEX L2");
        console2.log("=====================================");
        console2.log("Deployer:", deployer);
        console2.log("Bridge:", bridge);
        console2.log("L1 Chain ID:", l1ChainId);
        console2.log("Initial Liquidity ETH:", initialLiquidityETH);
        console2.log("Initial Liquidity Token:", initialLiquidityToken);
        console2.log("Handler Token Reserve:", handlerTokenReserve);
        console2.log("");

        // Deploy SwapTokenL2 with deployer as minter
        SwapTokenL2 swapTokenL2 =
            new SwapTokenL2("Bridged Swap Token", "bSWAP", deployer, 0);
        swapTokenL2_ = address(swapTokenL2);
        console2.log("SwapTokenL2 deployed at:", swapTokenL2_);

        // Deploy SimpleDEX
        SimpleDEX dex = new SimpleDEX(swapTokenL2_, deployer);
        dex_ = address(dex);
        console2.log("SimpleDEX deployed at:", dex_);

        // Deploy L2 Handler
        CrossChainSwapHandlerL2 l2Handler =
            new CrossChainSwapHandlerL2(bridge, l1ChainId, dex_, deployer);
        l2Handler_ = address(l2Handler);
        console2.log("CrossChainSwapHandlerL2 deployed at:", l2Handler_);

        // Mint tokens for DEX liquidity
        swapTokenL2.mint(deployer, initialLiquidityToken);
        console2.log("Minted", initialLiquidityToken, "tokens for liquidity");

        // Approve and add liquidity to DEX
        swapTokenL2.approve(dex_, initialLiquidityToken);
        dex.addLiquidity{ value: initialLiquidityETH }(initialLiquidityToken);
        console2.log("Added liquidity to DEX");
        console2.log("  ETH:", initialLiquidityETH);
        console2.log("  Token:", initialLiquidityToken);

        // Mint tokens for L2Handler (for TOKEN->ETH swaps)
        // These represent "virtual" tokens that match L1 locked tokens
        swapTokenL2.mint(l2Handler_, handlerTokenReserve);
        console2.log("Minted", handlerTokenReserve, "tokens to L2Handler");

        // Approve DEX to spend L2Handler's tokens
        l2Handler.approveTokenForDEX();
        console2.log("Approved DEX to spend L2Handler tokens");

        // Write deployment addresses
        writeJson("SwapTokenL2", swapTokenL2_);
        writeJson("SimpleDEX", dex_);
        writeJson("CrossChainSwapHandlerL2", l2Handler_);

        console2.log("");
        console2.log("=====================================");
        console2.log("Deployment Complete");
        console2.log("=====================================");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Set L2Handler address on L1Handler");
        console2.log("2. Set L1Handler address on L2Handler");
    }

    /// @dev Writes an address to the deployment JSON file
    function writeJson(string memory name, address addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/cross-chain-dex-l2.json")
        );
    }
}
