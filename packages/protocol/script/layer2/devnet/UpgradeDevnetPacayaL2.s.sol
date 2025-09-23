// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/common/DefaultResolver.sol";
import "src/shared/signal/SignalService.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/tokenvault/BridgedERC20.sol";
import "src/shared/tokenvault/BridgedERC721.sol";
import "src/shared/tokenvault/ERC1155Vault.sol";
import "src/shared/tokenvault/ERC20Vault.sol";
import "src/shared/tokenvault/ERC721Vault.sol";
// Commenting out to avoid IBondManager naming conflict
// import "src/layer2/based/anchor/TaikoAnchor.sol";

contract UpgradeDevnetPacayaL2 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    uint64 public pacayaForkHeight = uint64(vm.envUint("PACAYA_FORK_HEIGHT"));
    uint64 public shastaForkHeight = uint64(vm.envUint("SHASTA_FORK_HEIGHT"));
    address public taikoAnchor = vm.envAddress("TAIKO_ANCHOR");
    address public sharedResolver = vm.envAddress("SHARED_RESOLVER");
    address public bridgeL2 = vm.envAddress("BRIDGE_L2");
    address public signalService = vm.envAddress("SIGNAL_SERVICE");
    address public erc20Vault = vm.envAddress("ERC20_VAULT");
    address public erc721Vault = vm.envAddress("ERC721_VAULT");
    address public erc1155Vault = vm.envAddress("ERC1155_VAULT");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        require(taikoAnchor != address(0), "invalid taiko anchor");
        require(sharedResolver != address(0), "invalid shared resolver");
        require(bridgeL2 != address(0), "invalid bridge");
        require(signalService != address(0), "invalid signal service");
        require(erc20Vault != address(0), "invalid erc20 vault");
        require(erc721Vault != address(0), "invalid erc721 vault");
        require(erc1155Vault != address(0), "invalid erc1155 vault");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Shared resolver
        UUPSUpgradeable(sharedResolver).upgradeTo(address(new DefaultResolver()));
        // Bridge
        UUPSUpgradeable(bridgeL2).upgradeTo(address(new Bridge(sharedResolver, signalService)));
        // SignalService
        UUPSUpgradeable(signalService).upgradeTo(address(new SignalService(sharedResolver)));
        // Vault
        UUPSUpgradeable(erc20Vault).upgradeTo(address(new ERC20Vault(sharedResolver)));
        UUPSUpgradeable(erc721Vault).upgradeTo(address(new ERC721Vault(sharedResolver)));
        UUPSUpgradeable(erc1155Vault).upgradeTo(address(new ERC1155Vault(sharedResolver)));
        // Bridged Token
        register(sharedResolver, "bridged_erc20", address(new BridgedERC20(address(erc20Vault))));
        register(sharedResolver, "bridged_erc721", address(new BridgedERC721(address(erc721Vault))));
        register(
            sharedResolver, "bridged_erc1155", address(new BridgedERC1155(address(erc1155Vault)))
        );
        // Register B_TAIKO
        register(sharedResolver, "taiko", taikoAnchor);

        // Taiko Anchor - commented out due to IBondManager naming conflict
        // Would need to resolve the conflict between layer1/based/IBondManager.sol
        // and shared/shasta/iface/IBondManager.sol before re-enabling
        // UUPSUpgradeable(taikoAnchor).upgradeTo(
        //     address(new TaikoAnchor(signalService, pacayaForkHeight, shastaForkHeight))
        // );
    }
}
