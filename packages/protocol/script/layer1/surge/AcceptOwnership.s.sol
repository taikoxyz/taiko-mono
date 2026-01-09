// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title AcceptOwnership
/// @notice Script to accept ownership of multiple contracts that use Ownable2Step pattern.
/// @dev Supports two modes:
///      1. Direct: calls acceptOwnership() on each contract (PRIVATE_KEY must be pending owner)
///      2. Intermediate: calls acceptOwnership(address[]) on INTERMEDIATE_CONTRACT which accepts
///         ownership of all specified contracts (permissionless, PRIVATE_KEY can be any account)
contract AcceptOwnership is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address[] internal contracts = vm.envAddress("CONTRACT_ADDRESSES", ",");
    address internal intermediateContract = vm.envAddress("INTERMEDIATE_CONTRACT");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(contracts.length > 0, "No contract addresses provided");

        console2.log("=====================================");
        console2.log("Accepting Ownership for", contracts.length, "contracts");
        console2.log("=====================================");

        if (intermediateContract != address(0)) {
            console2.log("Mode: Intermediate contract");
            console2.log("Intermediate:", intermediateContract);
            bytes memory data = abi.encodeWithSignature("acceptOwnership(address[])", (contracts));
            (bool success,) = intermediateContract.call(data);
            if (!success) {
                console2.log("Failed to accept ownership via intermediate contract");
                revert("");
            }
            console2.log("Accepted ownership for", contracts.length, "contracts via intermediate");
        } else {
            console2.log("Mode: Direct acceptance");
            for (uint256 i = 0; i < contracts.length; i++) {
                console2.log("Accepting ownership of:", contracts[i]);
                bytes memory data = abi.encodeWithSignature("acceptOwnership()");
                (bool success,) = contracts[i].call(data);
                if (!success) {
                    console2.log("Failed to accept ownership of:", contracts[i]);
                    revert("");
                }
            }
        }

        console2.log("=====================================");
        console2.log("Ownership Acceptance Complete");
        console2.log("=====================================");
    }
}
