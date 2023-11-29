// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../contracts/common/AddressManager.sol";
import "../contracts/libs/LibDeployHelper.sol";

contract SetRemoteBridgeSuites is Script {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public addressManagerAddress = vm.envAddress("ADDRESS_MANAGER_ADDRESS");
    uint256[] public remoteChainIDs = vm.envUint("REMOTE_CHAIN_IDS", ",");
    address[] public remoteBridges = vm.envAddress("REMOTE_BRIDGES", ",");
    address[] public remoteERC20Vaults = vm.envAddress("REMOTE_ERC20_VAULTS", ",");
    address[] public remoteERC721Vaults = vm.envAddress("REMOTE_ERC721_VAULTS", ",");
    address[] public remoteERC1155Vaults = vm.envAddress("REMOTE_ERC1155_VAULTS", ",");

    function run() external {
        require(
            remoteChainIDs.length == remoteBridges.length, "invalid remote bridge addresses length"
        );
        require(
            remoteChainIDs.length == remoteERC20Vaults.length,
            "invalid remote ERC20Vault addresses length"
        );
        require(
            remoteChainIDs.length == remoteERC721Vaults.length,
            "invalid remote ERC721Vault addresses length"
        );
        require(
            remoteChainIDs.length == remoteERC1155Vaults.length,
            "invalid remote ERC1155Vault addresses length"
        );

        vm.startBroadcast(privateKey);

        for (uint256 i; i < remoteChainIDs.length; ++i) {
            uint64 chainid = uint64(remoteChainIDs[i]);

            LibDeployHelper.register(addressManagerAddress, "bridge", remoteBridges[i], chainid);

            LibDeployHelper.register(
                addressManagerAddress, "erc20_vault", remoteERC20Vaults[i], chainid
            );

            LibDeployHelper.register(
                addressManagerAddress, "erc721_vault", remoteERC721Vaults[i], chainid
            );

            LibDeployHelper.register(
                addressManagerAddress, "erc1155_vault", remoteERC1155Vaults[i], chainid
            );
        }

        vm.stopBroadcast();
    }
}
