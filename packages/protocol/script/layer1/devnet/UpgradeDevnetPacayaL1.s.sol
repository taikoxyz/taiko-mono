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
import "src/layer1/provers/ProverSet.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/devnet/verifiers/OpVerifier.sol";
import "src/layer1/devnet/verifiers/DevnetVerifier.sol";
import "src/layer1/based/ForkRouter.sol";
import "src/layer1/verifiers/compose/ComposeVerifier.sol";
import "src/layer1/devnet/DevnetInbox.sol";


contract UpgradeDevnetPacayaL1 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Rollup resolver
        address rollupResolver = 0x1F027871F286Cf4B7F898B21298E7B3e090a8403;
        UUPSUpgradeable(rollupResolver).upgradeTo(address(new DefaultResolver()));
        // TaikoInbox
        // TODO: find real old fork contract address
        address oldFork = 0x1F027871F286Cf4B7F898B21298E7B3e090a8403;
        address newFork = address(new DevnetInbox(rollupResolver));
        UUPSUpgradeable(0xA4702E22F8807Df82Fe5B6dDdd99eB3Fcb0237B0).upgradeTo(
            address(new ForkRouter(oldFork, newFork))
        );

        // Prover set
        UUPSUpgradeable(0xACFFB14Ca4b783fe7314855fBC38c50d7b7A8240).upgradeTo(
            address(new ProverSet(rollupResolver))
        );

        // Verifier
        TaikoInbox taikoInbox = TaikoInbox(payable(newFork));
        uint64 l2ChainId = taikoInbox.getConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");
        address opVerifier = deployProxy({
            name: "op_verifier",
            impl: address(new OpVerifier(rollupResolver, l2ChainId)),
            data: abi.encodeCall(OpVerifier.init, (address(0))),
            registerTo: rollupResolver
        });
        UUPSUpgradeable(0xebB0DA61818F639f460F67940EB269b36d1F104E).upgradeTo(
            address(new SgxVerifier(rollupResolver, l2ChainId))
        );
        register(rollupResolver, "sgx_verifier", 0xebB0DA61818F639f460F67940EB269b36d1F104E);
        UUPSUpgradeable(0xDf8038e9f4535040D7421A89ead398b3A38366EC).upgradeTo(
            address(new Risc0Verifier(rollupResolver, l2ChainId))
        );
        register(rollupResolver, "risc0_verifier", 0xDf8038e9f4535040D7421A89ead398b3A38366EC);
        UUPSUpgradeable(0x748d4a7e3a49adEbA2157B2d581434A6Cc226D1F).upgradeTo(
            address(new SP1Verifier(rollupResolver, l2ChainId))
        );
        register(rollupResolver, "sp1_verifier", 0x748d4a7e3a49adEbA2157B2d581434A6Cc226D1F);
        deployProxy({
            name: "proof_verifier",
            impl: address(
                new DevnetVerifier(
                    address(rollupResolver),
                    opVerifier,
                    0xebB0DA61818F639f460F67940EB269b36d1F104E,
                    0xDf8038e9f4535040D7421A89ead398b3A38366EC,
                    0x748d4a7e3a49adEbA2157B2d581434A6Cc226D1F
                )
            ),
            data: abi.encodeCall(ComposeVerifier.init, (address(0))),
            registerTo: rollupResolver
        });

        // Shared resolver
        address sharedResolver = 0x9bcED1c37F03c0527e0A4070424992F517c3B122;
        UUPSUpgradeable(sharedResolver).upgradeTo(address(new DefaultResolver()));
        // Bridge
        UUPSUpgradeable(0x1c406D71342D2C368e3B35F5c3F573E51Aa2E88f).upgradeTo(
            address(new Bridge(sharedResolver))
        );
        // SignalService
        UUPSUpgradeable(0x3DA89a777B11aABa02B5C92Fab96545D05fd4cc6).upgradeTo(
            address(new SignalService(sharedResolver))
        );
        // Vault
        UUPSUpgradeable(0x604C61d6618AaCdF7a7A2Fe4c42E35Ecba32AE75).upgradeTo(
            address(new ERC20Vault(sharedResolver))
        );
        UUPSUpgradeable(0xf7f1b1Cf92f24aa4BFf028eAAEF15a6159045fC7).upgradeTo(
            address(new ERC721Vault(sharedResolver))
        );
        UUPSUpgradeable(0x63df6E0d2291455ABbc3e406972b8a0fE807a235).upgradeTo(
            address(new ERC1155Vault(sharedResolver))
        );
        // Bridged Token
        register(
            sharedResolver, "bridged_erc20", address(new BridgedERC20(address(sharedResolver)))
        );
        register(
            sharedResolver, "bridged_erc721", address(new BridgedERC721(address(sharedResolver)))
        );
        register(
            sharedResolver, "bridged_erc1155", address(new BridgedERC1155(address(sharedResolver)))
        );
    }
}
