// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../test/shared/DeployCapability.sol";

contract SetRemoteBridgeSuites is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    uint256 public securityCouncilPrivateKey = vm.envUint("SECURITY_COUNCIL_PRIVATE_KEY");
    address public addressManagerAddress = vm.envAddress("ADDRESS_MANAGER_ADDRESS");
    uint256[] public remoteChainIDs = vm.envUint("REMOTE_CHAIN_IDS", ",");
    address[] public remoteSignalServices = vm.envAddress("REMOTE_SIGNAL_SERVICES", ",");
    address[] public remoteBridges = vm.envAddress("REMOTE_BRIDGES", ",");
    address[] public remoteERC20Vaults = vm.envAddress("REMOTE_ERC20_VAULTS", ",");
    address[] public remoteERC721Vaults = vm.envAddress("REMOTE_ERC721_VAULTS", ",");
    address[] public remoteERC1155Vaults = vm.envAddress("REMOTE_ERC1155_VAULTS", ",");

    function run() external {
        require(
            remoteChainIDs.length == remoteBridges.length, "invalid remote bridge addresses length"
        );
        require(
            remoteChainIDs.length == remoteSignalServices.length,
            "invalid remote SignalService addresses length"
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
            register(addressManagerAddress, "signal_service", remoteSignalServices[i], chainid);
            register(addressManagerAddress, "bridge", remoteBridges[i], chainid);
            register(addressManagerAddress, "erc20_vault", remoteERC20Vaults[i], chainid);
            register(addressManagerAddress, "erc721_vault", remoteERC721Vaults[i], chainid);
            register(addressManagerAddress, "erc1155_vault", remoteERC1155Vaults[i], chainid);
        }

        vm.stopBroadcast();
    }
}
