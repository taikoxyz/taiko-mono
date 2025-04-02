// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/AddressManager.sol";
import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/bridge/Init3Bridge.sol";
import "src/shared/tokenvault/Init3ERC20Vault.sol";
import "src/shared/tokenvault/Init3ERC721Vault.sol";
import "src/shared/tokenvault/Init3ERC1155Vault.sol";
import "src/shared/tokenvault/Init3BridgedERC20.sol";
import "src/shared/tokenvault/Init3BridgedERC721.sol";
import "src/shared/tokenvault/Init3BridgedERC1155.sol";

contract DeployHeklaAddressManagerL2 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public sharedResolver = 0x1670090000000000000000000000000000000006;
    address public delegateOwner = 0x95F6077C7786a58FA070D98043b16DF2B1593D2b;

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address sharedAddressManager = deployProxy({
            name: "shared_address_manager",
            impl: address(new AddressManager()),
            data: abi.encodeCall(AddressManager.init, (address(0)))
        });
        address rollupAddressManager = deployProxy({
            name: "rollup_address_manager",
            impl: address(new AddressManager()),
            data: abi.encodeCall(AddressManager.init, (address(0)))
        });
        // register copy
        register(sharedAddressManager, "bridge", 0x1670090000000000000000000000000000000001);
        register(sharedAddressManager, "signal_service", 0x1670090000000000000000000000000000000005);
        register(sharedAddressManager, "erc20_vault", 0x1670090000000000000000000000000000000002);
        register(sharedAddressManager, "erc721_vault", 0x1670090000000000000000000000000000000003);
        register(sharedAddressManager, "erc1155_vault", 0x1670090000000000000000000000000000000004);
        register(sharedAddressManager, "bridged_erc20", 0x1BAF1AB3686Ace2fD47E11Ac627F3Cc626aEc0FF);
        register(sharedAddressManager, "bridged_erc721", 0x45327BDbe23c1a3F0b437C78a19E813f9b11E566);
        register(sharedAddressManager, "bridged_erc1155", 0xb190786090Fc4308c4C40808f3bEB55c4463c152);
        register(sharedAddressManager, "taiko", 0x1670090000000000000000000000000000010001);
        register(rollupAddressManager, "bridge", 0x1670090000000000000000000000000000000001);
        register(rollupAddressManager, "signal_service", 0x1670090000000000000000000000000000000005);
        register(rollupAddressManager, "erc20_vault", 0x1670090000000000000000000000000000000002);
        register(rollupAddressManager, "erc721_vault", 0x1670090000000000000000000000000000000003);
        register(rollupAddressManager, "erc1155_vault", 0x1670090000000000000000000000000000000004);
        register(rollupAddressManager, "bridged_erc20", 0x1BAF1AB3686Ace2fD47E11Ac627F3Cc626aEc0FF);
        register(rollupAddressManager, "bridged_erc721", 0x45327BDbe23c1a3F0b437C78a19E813f9b11E566);
        register(rollupAddressManager, "bridged_erc1155", 0xb190786090Fc4308c4C40808f3bEB55c4463c152);
        register(rollupAddressManager, "taiko", 0x1670090000000000000000000000000000010001);
        // transfer ownership
        Ownable2StepUpgradeable(sharedAddressManager).transferOwnership(delegateOwner);
        Ownable2StepUpgradeable(rollupAddressManager).transferOwnership(delegateOwner);
        // Bridge
        address init3BridgeImpl = address(new Init3Bridge());
        console2.log("init3_bridge", init3BridgeImpl);
        // Vault token
        address init3ERC20Vault = address(new Init3ERC20Vault());
        console2.log("init3_erc20_vault", init3ERC20Vault);
        address init3ERC721Vault = address(new Init3ERC721Vault());
        console2.log("init3_erc721_vault", init3ERC721Vault);
        address init3ERC1155Vault = address(new Init3ERC1155Vault());
        console2.log("init3_erc1155_vault", init3ERC1155Vault);
        // Bridged token
        address init3BridgedERC20 = address(new Init3BridgedERC20());
        console2.log("init3_bridged_erc20", init3BridgedERC20);
        address init3BridgedERC721 = address(new Init3BridgedERC721());
        console2.log("init3_bridged_erc721", init3BridgedERC721);
        address init3BridgedERC1155 = address(new Init3BridgedERC1155());
        console2.log("init3_bridged_erc1155", init3BridgedERC1155);
    }
}
