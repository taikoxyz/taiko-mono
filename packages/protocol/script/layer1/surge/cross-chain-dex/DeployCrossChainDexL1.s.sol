// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SwapToken } from
    "../../../../contracts/layer1/surge/cross-chain-dex/SwapToken.sol";
import { CrossChainSwapHandlerL1 } from
    "../../../../contracts/layer1/surge/cross-chain-dex/CrossChainSwapHandlerL1.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title DeployCrossChainDexL1
/// @notice Script to deploy the Cross-Chain DEX L1 contracts
contract DeployCrossChainDexL1 is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal immutable bridge = vm.envAddress("L1_BRIDGE");
    uint64 internal immutable l2ChainId = uint64(vm.envUint("L2_CHAIN_ID"));
    uint256 internal immutable initialTokenSupply = vm.envUint("INITIAL_TOKEN_SUPPLY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run()
        external
        broadcast
        returns (address swapToken_, address l1Handler_)
    {
        address deployer = vm.addr(privateKey);

        console2.log("=====================================");
        console2.log("Deploying Cross-Chain DEX L1");
        console2.log("=====================================");
        console2.log("Deployer:", deployer);
        console2.log("Bridge:", bridge);
        console2.log("L2 Chain ID:", l2ChainId);
        console2.log("Initial Token Supply:", initialTokenSupply);
        console2.log("");

        // Deploy SwapToken
        SwapToken swapToken = new SwapToken("Swap Token", "SWAP", deployer, 0);
        swapToken_ = address(swapToken);
        console2.log("SwapToken deployed at:", swapToken_);

        // Deploy L1 Handler
        CrossChainSwapHandlerL1 l1Handler =
            new CrossChainSwapHandlerL1(bridge, l2ChainId, swapToken_, deployer);
        l1Handler_ = address(l1Handler);
        console2.log("CrossChainSwapHandlerL1 deployed at:", l1Handler_);

        // Mint initial supply to L1Handler (reserves for ETH->Token swaps)
        swapToken.mint(l1Handler_, initialTokenSupply);
        console2.log("Minted", initialTokenSupply, "tokens to L1Handler");

        // Write deployment addresses
        writeJson("SwapToken", swapToken_);
        writeJson("CrossChainSwapHandlerL1", l1Handler_);

        console2.log("");
        console2.log("=====================================");
        console2.log("Deployment Complete");
        console2.log("=====================================");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Deploy L2 contracts using deploy_cross_chain_dex_l2.sh");
        console2.log("2. Set L2Handler address on L1Handler");
        console2.log("3. Set L1Handler address on L2Handler");
    }

    /// @dev Writes an address to the deployment JSON file
    function writeJson(string memory name, address addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/cross-chain-dex-l1.json")
        );
    }
}
