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
import "src/layer2/based/TaikoAnchor.sol";
import "src/layer2/DelegateOwner.sol";

contract DeployMainnetPacayaL2 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    uint64 public pacayaForkHeight = 1_163_968;
    address public signalService = 0x1670000000000000000000000000000000000005;
    address public contractOwner = vm.envAddress("CONTRACT_OWNER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        require(signalService != address(0), "invalid signal service");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Shared resolver
        address sharedResolver = deployProxy({
            name: "shared_resolver",
            impl: address(new DefaultResolver()),
            data: abi.encodeCall(DefaultResolver.init, (address(0)))
        });
        // Rollup resolver
        address rollupResolver = deployProxy({
            name: "rollup_resolver",
            impl: address(new DefaultResolver()),
            data: abi.encodeCall(DefaultResolver.init, (address(0)))
        });
        // Copy register
        register(sharedResolver, "bridge", 0x1670000000000000000000000000000000000001);
        register(sharedResolver, "signal_service", 0x1670000000000000000000000000000000000005);
        register(sharedResolver, "erc20_vault", 0x1670000000000000000000000000000000000002);
        register(sharedResolver, "erc721_vault", 0x1670000000000000000000000000000000000003);
        register(sharedResolver, "erc1155_vault", 0x1670000000000000000000000000000000000004);
        register(sharedResolver, "bridged_erc20", 0x98161D67f762A9E589E502348579FA38B1Ac47A8);
        register(sharedResolver, "bridged_erc721", 0x0167000000000000000000000000000000010097);
        register(sharedResolver, "bridged_erc1155", 0x0167000000000000000000000000000000010098);
        register(sharedResolver, "taiko", 0x1670000000000000000000000000000000010001);
        register(sharedResolver, "taiko_token", 0xA9d23408b9bA935c230493c40C73824Df71A0975);
        register(sharedResolver, "bond_token", 0xA9d23408b9bA935c230493c40C73824Df71A0975);
        register(sharedResolver, "bridge", 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC, 1);
        register(sharedResolver, "signal_service", 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C, 1);
        register(sharedResolver, "erc20_vault", 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab, 1);
        register(sharedResolver, "erc721_vault", 0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa, 1);
        register(sharedResolver, "erc1155_vault", 0xaf145913EA4a56BE22E120ED9C24589659881702, 1);
        register(sharedResolver, "bridged_erc20", 0x65666141a541423606365123Ed280AB16a09A2e1, 1);
        register(sharedResolver, "bridged_erc721", 0xC3310905E2BC9Cfb198695B75EF3e5B69C6A1Bf7, 1);
        register(sharedResolver, "bridged_erc1155", 0x3c90963cFBa436400B0F9C46Aa9224cB379c2c40, 1);
        register(rollupResolver, "bridge", 0x1670000000000000000000000000000000000001);
        register(rollupResolver, "signal_service", 0x1670000000000000000000000000000000000005);
        register(rollupResolver, "erc20_vault", 0x1670000000000000000000000000000000000002);
        register(rollupResolver, "erc721_vault", 0x1670000000000000000000000000000000000003);
        register(rollupResolver, "erc1155_vault", 0x1670000000000000000000000000000000000004);
        register(rollupResolver, "bridged_erc20", 0x98161D67f762A9E589E502348579FA38B1Ac47A8);
        register(rollupResolver, "bridged_erc721", 0x0167000000000000000000000000000000010097);
        register(rollupResolver, "bridged_erc1155", 0x0167000000000000000000000000000000010098);
        register(rollupResolver, "taiko", 0x1670000000000000000000000000000000010001);
        register(rollupResolver, "taiko_token", 0xA9d23408b9bA935c230493c40C73824Df71A0975);
        register(rollupResolver, "bond_token", 0xA9d23408b9bA935c230493c40C73824Df71A0975);
        register(rollupResolver, "bridge", 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC, 1);
        register(rollupResolver, "signal_service", 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C, 1);
        register(rollupResolver, "erc20_vault", 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab, 1);
        register(rollupResolver, "erc721_vault", 0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa, 1);
        register(rollupResolver, "erc1155_vault", 0xaf145913EA4a56BE22E120ED9C24589659881702, 1);
        register(rollupResolver, "bridged_erc20", 0x65666141a541423606365123Ed280AB16a09A2e1, 1);
        register(rollupResolver, "bridged_erc721", 0xC3310905E2BC9Cfb198695B75EF3e5B69C6A1Bf7, 1);
        register(rollupResolver, "bridged_erc1155", 0x3c90963cFBa436400B0F9C46Aa9224cB379c2c40, 1);
        // SignalService
        address signalServiceImpl = address(new SignalService(sharedResolver));
        console2.log("signalServiceImpl", signalServiceImpl);
        // Taiko Anchor
        address taikoAnchorImpl =
            address(new TaikoAnchor(sharedResolver, signalService, pacayaForkHeight));
        console2.log("taikoAnchor", taikoAnchorImpl);

        // Transfer ownership
        Ownable2StepUpgradeable(sharedResolver).transferOwnership(contractOwner);
        Ownable2StepUpgradeable(rollupResolver).transferOwnership(contractOwner);
    }
}
