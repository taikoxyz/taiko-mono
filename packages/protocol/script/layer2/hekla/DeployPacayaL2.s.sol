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

contract DeployPacayaL2 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    uint64 public pacayaForkHeight = uint64(vm.envUint("PACAYA_FORK_HEIGHT"));
    address public signalService = vm.envAddress("SIGNAL_SERVICE");

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
        register(sharedResolver, "bridge", 0x1670090000000000000000000000000000000001);
        register(sharedResolver, "signal_service", 0x1670090000000000000000000000000000000005);
        register(sharedResolver, "erc20_vault", 0x1670090000000000000000000000000000000002);
        register(sharedResolver, "erc721_vault", 0x1670090000000000000000000000000000000003);
        register(sharedResolver, "erc1155_vault", 0x1670090000000000000000000000000000000004);
        register(sharedResolver, "bridged_erc20", 0x1BAF1AB3686Ace2fD47E11Ac627F3Cc626aEc0FF);
        register(sharedResolver, "bridged_erc721", 0x45327BDbe23c1a3F0b437C78a19E813f9b11E566);
        register(sharedResolver, "bridged_erc1155", 0xb190786090Fc4308c4C40808f3bEB55c4463c152);
        register(sharedResolver, "taiko", 0x1670090000000000000000000000000000010001);
        register(sharedResolver, "bridge", 0xA098b76a3Dd499D3F6D58D8AcCaFC8efBFd06807, 17_000);
        register(
            sharedResolver, "signal_service", 0x6Fc2fe9D9dd0251ec5E0727e826Afbb0Db2CBe0D, 17_000
        );
        register(sharedResolver, "erc20_vault", 0x2259662ed5dE0E09943Abe701bc5f5a108eABBAa, 17_000);
        register(sharedResolver, "erc721_vault", 0x046b82D9010b534c716742BE98ac3FEf3f2EC99f, 17_000);
        register(
            sharedResolver, "erc1155_vault", 0x9Ae5945Ab34f6182F75E16B73e037421F341fEe3, 17_000
        );
        register(
            sharedResolver, "bridged_erc20", 0xe3661857941E4A711fa6b4Fc080bC5c5948a70f1, 17_000
        );
        register(
            sharedResolver, "bridged_erc721", 0xbD832CAf65c8a73609EFd62E2A4FCB1292e4c9C1, 17_000
        );
        register(
            sharedResolver, "bridged_erc1155", 0x0B5B063dc89EcfCedf8aF570d82598F72a7dfF35, 17_000
        );
        register(rollupResolver, "bridge", 0x1670090000000000000000000000000000000001);
        register(rollupResolver, "signal_service", 0x1670090000000000000000000000000000000005);
        register(rollupResolver, "erc20_vault", 0x1670090000000000000000000000000000000002);
        register(rollupResolver, "erc721_vault", 0x1670090000000000000000000000000000000003);
        register(rollupResolver, "erc1155_vault", 0x1670090000000000000000000000000000000004);
        register(rollupResolver, "bridged_erc20", 0x1BAF1AB3686Ace2fD47E11Ac627F3Cc626aEc0FF);
        register(rollupResolver, "bridged_erc721", 0x45327BDbe23c1a3F0b437C78a19E813f9b11E566);
        register(rollupResolver, "bridged_erc1155", 0xb190786090Fc4308c4C40808f3bEB55c4463c152);
        register(rollupResolver, "taiko", 0x1670090000000000000000000000000000010001);
        register(rollupResolver, "bridge", 0xA098b76a3Dd499D3F6D58D8AcCaFC8efBFd06807, 17_000);
        register(
            rollupResolver, "signal_service", 0x6Fc2fe9D9dd0251ec5E0727e826Afbb0Db2CBe0D, 17_000
        );
        register(rollupResolver, "erc20_vault", 0x2259662ed5dE0E09943Abe701bc5f5a108eABBAa, 17_000);
        register(rollupResolver, "erc721_vault", 0x046b82D9010b534c716742BE98ac3FEf3f2EC99f, 17_000);
        register(
            rollupResolver, "erc1155_vault", 0x9Ae5945Ab34f6182F75E16B73e037421F341fEe3, 17_000
        );
        register(
            rollupResolver, "bridged_erc20", 0xe3661857941E4A711fa6b4Fc080bC5c5948a70f1, 17_000
        );
        register(
            rollupResolver, "bridged_erc721", 0xbD832CAf65c8a73609EFd62E2A4FCB1292e4c9C1, 17_000
        );
        register(
            rollupResolver, "bridged_erc1155", 0x0B5B063dc89EcfCedf8aF570d82598F72a7dfF35, 17_000
        );
        // SignalService
        address signalServiceImpl = address(new SignalService(sharedResolver));
        console2.log("signalService", signalServiceImpl);
        // Taiko Anchor
        address taikoAnchorImpl =
            address(new TaikoAnchor(sharedResolver, signalService, pacayaForkHeight));
        console2.log("taikoAnchor", taikoAnchorImpl);
    }
}
