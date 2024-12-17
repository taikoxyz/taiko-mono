// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import { SP1Verifier as SuccinctVerifier } from "@sp1-contracts/src/v3.0.0/SP1VerifierPlonk.sol";

// Actually this one is deployed already on mainnet, but we are now deploying our own (non via-ir)
// version. For mainnet, it is easier to go with one of:
// - https://github.com/daimo-eth/p256-verifier
// - https://github.com/rdubois-crypto/FreshCryptoLib
import "@p256-verifier/contracts/P256Verifier.sol";

import "src/shared/common/DefaultResolver.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/tokenvault/BridgedERC20.sol";
import "src/shared/tokenvault/BridgedERC721.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";
import "src/layer1/devnet/DevnetTaikoInbox.sol";
import "src/layer1/mainnet/MainnetInbox.sol";
import "src/layer1/based/TaikoInbox.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/mainnet/multirollup/MainnetBridge.sol";
import "src/layer1/mainnet/multirollup/MainnetERC1155Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetERC20Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetERC721Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetSignalService.sol";
import "src/layer1/provers/ProverSet.sol";
import "src/layer1/token/TaikoToken.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "test/shared/helpers/FreeMintERC20Token.sol";
import "test/shared/helpers/FreeMintERC20Token_With50PctgMintAndTransferFailure.sol";
import "test/shared/DeployCapability.sol";

/// @title DeployProtocolOnL1
/// @notice This script deploys the core Taiko protocol smart contract on L1,
/// initializing the rollup.
contract DeployProtocolOnL1 is DeployCapability {
    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        addressNotNull(vm.envAddress("TAIKO_ANCHOR_ADDRESS"), "TAIKO_ANCHOR_ADDRESS");
        addressNotNull(vm.envAddress("L2_SIGNAL_SERVICE"), "L2_SIGNAL_SERVICE");
        addressNotNull(vm.envAddress("CONTRACT_OWNER"), "CONTRACT_OWNER");

        require(vm.envBytes32("L2_GENESIS_HASH") != 0, "L2_GENESIS_HASH");
        address contractOwner = vm.envAddress("CONTRACT_OWNER");

        // ---------------------------------------------------------------
        // Deploy shared contracts
        (address sharedResolver) = deploySharedContracts(contractOwner);
        console2.log("sharedResolver: ", sharedResolver);
        // ---------------------------------------------------------------
        // Deploy rollup contracts
        address rollupResolver = deployRollupContracts(sharedResolver, contractOwner);

        // ---------------------------------------------------------------
        // Signal service need to authorize the new rollup
        address signalServiceAddr = DefaultResolver(sharedResolver).getAddress(
            uint64(block.chainid), LibStrings.B_SIGNAL_SERVICE
        );
        addressNotNull(signalServiceAddr, "signalServiceAddr");
        SignalService signalService = SignalService(signalServiceAddr);

        address taikoInboxAddr =
            DefaultResolver(rollupResolver).getAddress(uint64(block.chainid), LibStrings.B_TAIKO);
        addressNotNull(taikoInboxAddr, "taikoInboxAddr");
        TaikoInbox taikoInbox = TaikoInbox(payable(taikoInboxAddr));

        if (vm.envAddress("SHARED_ADDRESS_RESOLVER") == address(0)) {
            SignalService(signalServiceAddr).authorize(taikoInboxAddr, true);
        }

        uint64 l2ChainId = taikoInbox.getConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        console2.log("------------------------------------------");
        console2.log("msg.sender: ", msg.sender);
        console2.log("address(this): ", address(this));
        console2.log("signalService.owner(): ", signalService.owner());
        console2.log("------------------------------------------");

        if (signalService.owner() == msg.sender) {
            signalService.transferOwnership(contractOwner);
        } else {
            console2.log("------------------------------------------");
            console2.log("Warning - you need to transact manually:");
            console2.log("signalService.authorize(taikoInboxAddr, bytes32(block.chainid))");
            console2.log("- signalService : ", signalServiceAddr);
            console2.log("- taikoInboxAddr   : ", taikoInboxAddr);
            console2.log("- chainId       : ", block.chainid);
        }

        // ---------------------------------------------------------------
        // Register L2 addresses
        register(rollupResolver, LibString.B_TAIKO, vm.envAddress("TAIKO_L2_ADDRESS"), l2ChainId);
        register(
            rollupResolver,
            LibString.B_SIGNAL_SERVICE,
            vm.envAddress("L2_SIGNAL_SERVICE"),
            l2ChainId
        );

        // ---------------------------------------------------------------
        // Deploy other contracts
        if (block.chainid != 1) {
            deployAuxContracts();
        }

        if (DefaultResolver(sharedResolver).owner() == msg.sender) {
            DefaultResolver(sharedResolver).transferOwnership(contractOwner);
            console2.log("** sharedResolver ownership transferred to:", contractOwner);
        }

        DefaultResolver(rollupResolver).transferOwnership(contractOwner);
        console2.log("** rollupResolver ownership transferred to:", contractOwner);
    }

    function deploySharedContracts(address owner) internal returns (address sharedResolver) {
        addressNotNull(owner, "owner");

        sharedResolver = vm.envAddress("SHARED_RESOLVER");
        if (sharedResolver == address(0)) {
            sharedResolver = deployProxy({
                name: "shared_resolver",
                impl: address(new DefaultResolver()),
                data: abi.encodeCall(DefaultResolver.init, (address(0)))
            });
        }

        address taikoToken = vm.envAddress("TAIKO_TOKEN");
        if (taikoToken == address(0)) {
            taikoToken = deployProxy({
                name: LibString.B_TAIKO_TOKEN,
                impl: address(new TaikoToken()),
                data: abi.encodeCall(
                    TaikoToken.init, (owner, vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT"))
                ),
                registerTo: sharedResolver
            });
        } else {
            register(sharedResolver, LibString.B_TAIKO_TOKEN, taikoToken);
        }
        register(sharedResolver, LibString.B_BOND_TOKEN, taikoToken);

        // Deploy Bridging contracts
        deployProxy({
            name: LibString.B_SIGNAL_SERVICE,
            impl: address(new MainnetSignalService()),
            data: abi.encodeCall(MainnetSignalService.init, (address(0), sharedResolver)),
            registerTo: sharedResolver
        });

        address brdige = deployProxy({
            name: LibString.B_BRIDGE,
            impl: address(new MainnetBridge()),
            data: abi.encodeCall(MainnetBridge.init, (address(0), sharedResolver)),
            registerTo: sharedResolver
        });

        if (vm.envBool("PAUSE_BRIDGE")) {
            Bridge(payable(brdige)).pause();
        }

        Bridge(payable(brdige)).transferOwnership(owner);

        console2.log("------------------------------------------");
        console2.log(
            "Warning - you need to register *all* counterparty bridges to enable multi-hop bridging:"
        );
        console2.log(
            "sharedResolver.registerAddress(remoteChainId, \"bridge\", address(remoteBridge))"
        );
        console2.log("- sharedResolver : ", sharedResolver);

        // Deploy Vaults
        deployProxy({
            name: LibString.B_ERC20_VAULT,
            impl: address(new MainnetERC20Vault()),
            data: abi.encodeCall(MainnetERC20Vault.init, (owner, sharedResolver)),
            registerTo: sharedResolver
        });

        deployProxy({
            name: LibString.B_ERC721_VAULT,
            impl: address(new MainnetERC721Vault()),
            data: abi.encodeCall(MainnetERC721Vault.init, (owner, sharedResolver)),
            registerTo: sharedResolver
        });

        deployProxy({
            name: LibString.B_ERC1155_VAULT,
            impl: address(new MainnetERC1155Vault()),
            data: abi.encodeCall(MainnetERC1155Vault.init, (owner, sharedResolver)),
            registerTo: sharedResolver
        });

        console2.log("------------------------------------------");
        console2.log(
            "Warning - you need to register *all* counterparty vaults to enable multi-hop bridging:"
        );
        console2.log(
            "sharedResolver.registerAddress(remoteChainId, \"erc20_vault\", address(remoteERC20Vault))"
        );
        console2.log(
            "sharedResolver.registerAddress(remoteChainId, \"erc721_vault\", address(remoteERC721Vault))"
        );
        console2.log(
            "sharedResolver.registerAddress(remoteChainId, \"erc1155_vault\", address(remoteERC1155Vault))"
        );
        console2.log("- sharedResolver : ", sharedResolver);

        // Deploy Bridged token implementations
        register(sharedResolver, LibString.B_BRIDGED_ERC20, address(new BridgedERC20()));
        register(sharedResolver, LibString.B_BRIDGED_ERC721, address(new BridgedERC721()));
        register(sharedResolver, LibString.B_BRIDGED_ERC1155, address(new BridgedERC1155()));
    }

    function deployRollupContracts(
        address _sharedResolver,
        address owner
    )
        internal
        returns (address rollupResolver)
    {
        addressNotNull(_sharedResolver, "sharedResolver");
        addressNotNull(owner, "owner");

        rollupResolver = deployProxy({
            name: "rollup_address_resolver",
            impl: address(new DefaultResolver()),
            data: abi.encodeCall(DefaultResolver.init, (address(0)))
        });

        // ---------------------------------------------------------------
        // Register shared contracts in the new rollup resolver
        copyRegister(rollupResolver, _sharedResolver, LibString.B_TAIKO_TOKEN);
        copyRegister(rollupResolver, _sharedResolver, LibString.B_BOND_TOKEN);
        copyRegister(rollupResolver, _sharedResolver, LibString.B_SIGNAL_SERVICE);
        copyRegister(rollupResolver, _sharedResolver, LibString.B_BRIDGE);

        deployProxy({
            name: "mainnet_taiko",
            impl: address(new MainnetInbox()),
            data: abi.encodeCall(
                MainnetInbox.init,
                (owner, rollupResolver, vm.envBytes32("L2_GENESIS_HASH"), vm.envBool("PAUSE_TAIKO_L1"))
            )
        });

        TaikoInbox taikoInbox = TaikoInbox(address(new DevnetTaikoInbox()));

        deployProxy({
            name: LibString.B_TAIKO,
            impl: address(taikoInbox),
            data: abi.encodeCall(
                TaikoInbox.init,
                (owner, rollupResolver, vm.envBytes32("L2_GENESIS_HASH"), vm.envBool("PAUSE_TAIKO_L1"))
            ),
            registerTo: rollupResolver
        });

        deployProxy({
            name: LibString.B_PROVER_SET,
            impl: address(new ProverSet()),
            data: abi.encodeCall(
                ProverSet.init, (owner, vm.envAddress("PROVER_SET_ADMIN"), rollupResolver)
            )
        });
    }

    function deployAuxContracts() private {
        address horseToken = address(new FreeMintERC20Token("Horse Token", "HORSE"));
        console2.log("HorseToken", horseToken);

        address bullToken =
            address(new FreeMintERC20Token_With50PctgMintAndTransferFailure("Bull Token", "BULL"));
        console2.log("BullToken", bullToken);
    }

    function addressNotNull(address addr, string memory err) private pure {
        require(addr != address(0), err);
    }
}
