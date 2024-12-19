// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";
import "src/shared/common/DefaultResolver.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/tokenvault/BridgedERC20.sol";
import "src/shared/tokenvault/BridgedERC721.sol";
import "src/layer1/devnet/DevnetInbox.sol";
import "src/layer1/mainnet/MainnetInbox.sol";
import "src/layer1/based/TaikoInbox.sol";
import "src/layer1/mainnet/multirollup/MainnetBridge.sol";
import "src/layer1/mainnet/multirollup/MainnetERC1155Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetERC20Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetERC721Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetSignalService.sol";
import "src/layer1/provers/ProverSet.sol";
import "src/layer1/token/TaikoToken.sol";
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
        address signalServiceAddr = EssentialContract(sharedResolver).resolve(
            uint64(block.chainid), LibStrings.B_SIGNAL_SERVICE, false
        );
        SignalService signalService = SignalService(signalServiceAddr);

        address taikoInboxAddr = EssentialContract(rollupResolver).resolve(
            uint64(block.chainid), LibStrings.B_TAIKO, false
        );
        TaikoInbox taikoInbox = TaikoInbox(payable(taikoInboxAddr));

        if (vm.envAddress("SHARED_RESOLVER") == address(0)) {
            SignalService(signalServiceAddr).authorize(taikoInboxAddr, true);
        }

        uint64 l2ChainId = taikoInbox.getConfigV3().chainId;
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
        register(rollupResolver, "taiko", vm.envAddress("TAIKO_ANCHOR_ADDRESS"), l2ChainId);
        register(rollupResolver, "signal_service", vm.envAddress("L2_SIGNAL_SERVICE"), l2ChainId);

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
                name: "taiko_token",
                impl: address(new TaikoToken()),
                data: abi.encodeCall(
                    TaikoToken.init, (owner, vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT"))
                ),
                registerTo: sharedResolver
            });
        } else {
            register(sharedResolver, "taiko_token", taikoToken);
        }
        register(sharedResolver, "bond_token", taikoToken);

        // Deploy Bridging contracts
        deployProxy({
            name: "signal_service",
            impl: address(new MainnetSignalService()),
            data: abi.encodeCall(SignalService.init, (address(0), sharedResolver)),
            registerTo: sharedResolver
        });

        address brdige = deployProxy({
            name: "bridge",
            impl: address(new MainnetBridge()),
            data: abi.encodeCall(Bridge.init, (address(0), sharedResolver)),
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
            name: "erc20_vault",
            impl: address(new MainnetERC20Vault()),
            data: abi.encodeCall(ERC20Vault.init, (owner, sharedResolver)),
            registerTo: sharedResolver
        });

        deployProxy({
            name: "erc721_vault",
            impl: address(new MainnetERC721Vault()),
            data: abi.encodeCall(ERC721Vault.init, (owner, sharedResolver)),
            registerTo: sharedResolver
        });

        deployProxy({
            name: "erc1155_vault",
            impl: address(new MainnetERC1155Vault()),
            data: abi.encodeCall(ERC1155Vault.init, (owner, sharedResolver)),
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
        register(sharedResolver, "bridged_erc20", address(new BridgedERC20()));
        register(sharedResolver, "bridged_erc721", address(new BridgedERC721()));
        register(sharedResolver, "bridged_erc1155", address(new BridgedERC1155()));
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
        copyRegister(rollupResolver, _sharedResolver, "taiko_token");
        copyRegister(rollupResolver, _sharedResolver, "bond_token");
        copyRegister(rollupResolver, _sharedResolver, "signal_service");
        copyRegister(rollupResolver, _sharedResolver, "bridge");

        deployProxy({
            name: "mainnet_taiko",
            impl: address(new MainnetInbox()),
            data: abi.encodeCall(
                TaikoInbox.init, (owner, rollupResolver, vm.envBytes32("L2_GENESIS_HASH"))
            )
        });

        TaikoInbox taikoInbox = TaikoInbox(address(new DevnetInbox()));

        deployProxy({
            name: "taiko",
            impl: address(taikoInbox),
            data: abi.encodeCall(
                TaikoInbox.init, (owner, rollupResolver, vm.envBytes32("L2_GENESIS_HASH"))
            ),
            registerTo: rollupResolver
        });

        deployProxy({
            name: "prover_set",
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
