// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

contract GetUsdcDomainSeparator is Script {
    function run() external view {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                // keccak256("EIP712Domain(string name,string version,uint256 chainId,address
                // verifyingContract)")
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256(bytes("USD Coin")),
                keccak256(bytes("2")),
                chainId,
                address(this)
            )
        );

        // Used during pre-deploy
        console2.log("DOMAIN_SEPARATOR:");
        console2.logBytes32(DOMAIN_SEPARATOR);
    }
}
