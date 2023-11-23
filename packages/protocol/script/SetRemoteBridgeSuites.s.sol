// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../contracts/common/AddressManager.sol";

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
            setAddress(addressManagerAddress, uint64(remoteChainIDs[i]), "bridge", remoteBridges[i]);
            setAddress(
                addressManagerAddress,
                uint64(remoteChainIDs[i]),
                "erc20_vault",
                remoteERC20Vaults[i]
            );
            setAddress(
                addressManagerAddress,
                uint64(remoteChainIDs[i]),
                "erc721_vault",
                remoteERC721Vaults[i]
            );
            setAddress(
                addressManagerAddress,
                uint64(remoteChainIDs[i]),
                "erc1155_vault",
                remoteERC1155Vaults[i]
            );
        }

        vm.stopBroadcast();
    }

    function setAddress(
        address addressManager,
        uint64 chainId,
        bytes32 name,
        address addr
    )
        private
    {
        console2.log(chainId, uint256(name), "--->", addr);
        AddressManager(addressManager).setAddress(chainId, name, addr);
    }
}
