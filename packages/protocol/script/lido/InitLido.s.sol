// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/DeployCapability.sol";

import { LidoL1Bridge } from "../../contracts/lido/LidoL1Bridge.sol";
import { LidoL2Bridge } from "../../contracts/lido/LidoL2Bridge.sol";
import { StandardERC20 } from "../../contracts/shared/token/StandardERC20.sol";

// FOUNDRY_PROFILE=lidol1 NETWORK=L1   forge script  script/lido/InitLido.s.sol --broadcast
// FOUNDRY_PROFILE=lidol2 NETWORK=L2   forge script  script/lido/InitLido.s.sol --broadcast

contract InitLido is DeployCapability {
    string private network = vm.envString("NETWORK");

    address private l1LidoBridgeAddress = vm.envAddress("L1_LIDO_BRIDGE_ADDRESS");
    address private l2LidoBridgeAddress = vm.envAddress("L2_LIDO_BRIDGE_ADDRESS");

    address private l1TokenAddress = vm.envAddress("L1_TOKEN_ADDRESS");
    address private l2TokenAddress = vm.envAddress("L2_TOKEN_ADDRESS");

    address private l2AdminAddress = vm.envAddress("L2_ADMIN_ADDRESS");
    address private l1AdminAddress = vm.envAddress("L1_ADMIN_ADDRESS");


    uint256 private l1DeployerPvtKey = vm.envUint("L1_DEPLOYER_PRIVATE_KEY");
    uint256 private l2DeployerPvtKey = vm.envUint("L2_DEPLOYER_PRIVATE_KEY");

    address private l1SharedAddressManager = vm.envAddress("L1_SHARED_ADDRESS_MANAGER");
    address private l2SharedAddressManager = vm.envAddress("L2_SHARED_ADDRESS_MANAGER");

    bytes32 public constant DEPOSITS_ENABLER_ROLE =
    keccak256("BridgingManager.DEPOSITS_ENABLER_ROLE");

    bytes32 public constant WITHDRAWALS_ENABLER_ROLE =
    keccak256("BridgingManager.WITHDRAWALS_ENABLER_ROLE");

    function run() external {
        if (keccak256(abi.encodePacked(network)) == keccak256(abi.encodePacked("L1"))) {
            vm.startBroadcast(l1DeployerPvtKey);
            LidoL1Bridge l1Lido = LidoL1Bridge(l1LidoBridgeAddress);

            (bool success,) = l1LidoBridgeAddress.call(abi.encodeCall(
                LidoL1Bridge.initialize, (
                l2LidoBridgeAddress,
                l1TokenAddress,
                l2TokenAddress,
                l1AdminAddress,
                l1SharedAddressManager)
            ));

            require(success, "Initialization failed");

            l1Lido.enableDeposits();
            l1Lido.enableWithdrawals();

            console.log("depositenabled", l1Lido.isDepositsEnabled());
            console.log("isWithdrawalsEnabled", l1Lido.isWithdrawalsEnabled());
        } else if (keccak256(abi.encodePacked(network)) == keccak256(abi.encodePacked("L2"))) {
            vm.startBroadcast(l2DeployerPvtKey);
            LidoL2Bridge l2Lido = LidoL2Bridge(l2LidoBridgeAddress);
            (bool success,) = l2LidoBridgeAddress.call(
                abi.encodeCall(
                    LidoL2Bridge.initialize,
                    (
                        l1LidoBridgeAddress,
                        l1TokenAddress,
                        l2TokenAddress,
                        l2AdminAddress,
                        l2SharedAddressManager
                    )
                )
            );

            require(success, "Initialization failed");

            l2Lido.enableDeposits();
            l2Lido.enableWithdrawals();


            (bool tokenInitSuccess,) = l2TokenAddress.call(
                abi.encodeCall(
                    StandardERC20.initialize,
                    (
                        "Wrapped liquid staked Ether 2.0",
                        "wstETH",
                        18,
                        l2LidoBridgeAddress,
                        l1LidoBridgeAddress
                    )
                )
            );

            require(tokenInitSuccess, "Token Init Initialization failed");
        }

        vm.stopBroadcast();
    }

    function logAddress(string memory name, address addr) internal view {
        console.log(string(abi.encodePacked(name, "=", vm.toString(address(addr)))));
    }
}
