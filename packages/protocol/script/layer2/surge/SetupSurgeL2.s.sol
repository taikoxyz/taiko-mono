// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Forge
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

// OpenZeppelin
import {
    Ownable2StepUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// Shared contracts
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";

// Layer2 contracts
import { DelegateController } from "src/layer2/governance/DelegateController.sol";

/// @title SetupSurgeL2
/// @notice This script is run on L2 and sets up the L2 contracts.
contract SetupSurgeL2 is Script {
    // Script configuration
    // --------------------------------------------------------------------------
    // Private key of the existing owner of the L2 contracts
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    // L1 configuration
    // --------------------------------------------------------------------------
    uint256 internal immutable l1ChainId = vm.envUint("L1_CHAINID");
    address internal immutable l1Bridge = vm.envAddress("L1_BRIDGE");
    address internal immutable l1SignalService = vm.envAddress("L1_SIGNAL_SERVICE");
    address internal immutable l1ERC20Vault = vm.envAddress("L1_ERC20_VAULT");
    address internal immutable l1ERC721Vault = vm.envAddress("L1_ERC721_VAULT");
    address internal immutable l1ERC1155Vault = vm.envAddress("L1_ERC1155_VAULT");

    // L1 Owner
    // --------------------------------------------------------------------------
    // This is the DAO controller (or any timelocked owner) on L1 that can send messages
    // to the L2 DelegateController
    // Incase of devnet, it would be a simple EOA
    address internal immutable l1Owner = vm.envAddress("L1_OWNER");

    struct L2Contract {
        bytes32 key;
        address addr;
    }

    struct L2ContractRegistry {
        L2Contract bridge;
        L2Contract erc20Vault;
        L2Contract erc721Vault;
        L2Contract erc1155Vault;
        L2Contract bridgedErc20;
        L2Contract bridgedErc721;
        L2Contract bridgedErc1155;
        L2Contract sharedResolver;
        L2Contract signalService;
        L2Contract taiko;
    }

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(l1ChainId != block.chainid || l1ChainId != 0, "config: L1_CHAIN_ID");
        require(l1Bridge != address(0), "config: L1_BRIDGE");
        require(l1SignalService != address(0), "config: L1_SIGNAL_SERVICE");
        require(l1ERC20Vault != address(0), "config: L1_ERC20_VAULT");
        require(l1ERC721Vault != address(0), "config: L1_ERC721_VAULT");
        require(l1ERC1155Vault != address(0), "config: L1_ERC1155_VAULT");

        L2ContractRegistry memory l2ContractRegistry = L2ContractRegistry({
            bridge: L2Contract({
                key: bytes32("bridge"), addr: getConstantAddress(vm.toString(block.chainid), "1")
            }),
            erc20Vault: L2Contract({
                key: bytes32("erc20_vault"),
                addr: getConstantAddress(vm.toString(block.chainid), "2")
            }),
            erc721Vault: L2Contract({
                key: bytes32("erc721_vault"),
                addr: getConstantAddress(vm.toString(block.chainid), "3")
            }),
            erc1155Vault: L2Contract({
                key: bytes32("erc1155_vault"),
                addr: getConstantAddress(vm.toString(block.chainid), "4")
            }),
            bridgedErc20: L2Contract({
                key: bytes32("bridged_erc20"),
                addr: getConstantAddress(string.concat("0", vm.toString(block.chainid)), "10096")
            }),
            bridgedErc721: L2Contract({
                key: bytes32("bridged_erc721"),
                addr: getConstantAddress(string.concat("0", vm.toString(block.chainid)), "10097")
            }),
            bridgedErc1155: L2Contract({
                key: bytes32("bridged_erc1155"),
                addr: getConstantAddress(string.concat("0", vm.toString(block.chainid)), "10098")
            }),
            sharedResolver: L2Contract({
                key: bytes32("shared_resolver"),
                addr: getConstantAddress(vm.toString(block.chainid), "6")
            }),
            signalService: L2Contract({
                key: bytes32("signal_service"),
                addr: getConstantAddress(vm.toString(block.chainid), "5")
            }),
            taiko: L2Contract({
                key: bytes32("taiko"), addr: getConstantAddress(vm.toString(block.chainid), "10001")
            })
        });

        // Verify L2 registrations
        // --------------------------------------------------------------------------
        verifyL2Registrations(l2ContractRegistry);

        // Register L1 contracts to L2 shared resolver
        // --------------------------------------------------------------------------
        registerL1ContractsToL2SharedResolver(l2ContractRegistry);

        // Setup delegate controller and transfer ownership
        // --------------------------------------------------------------------------
        setupDelegateControllerAndTransferOwnership(l2ContractRegistry);
    }

    function verifyL2Registrations(L2ContractRegistry memory l2ContractRegistry) internal view {
        L2Contract[10] memory contracts = [
            l2ContractRegistry.bridge,
            l2ContractRegistry.erc20Vault,
            l2ContractRegistry.erc721Vault,
            l2ContractRegistry.erc1155Vault,
            l2ContractRegistry.bridgedErc20,
            l2ContractRegistry.bridgedErc721,
            l2ContractRegistry.bridgedErc1155,
            l2ContractRegistry.sharedResolver,
            l2ContractRegistry.signalService,
            l2ContractRegistry.taiko
        ];

        for (uint256 i = 0; i < contracts.length; i++) {
            // Skip shared resolver verification because it's not registered to itself
            if (contracts[i].key == bytes32("shared_resolver")) {
                continue;
            }

            address resolved = DefaultResolver(l2ContractRegistry.sharedResolver.addr)
                .resolve(block.chainid, contracts[i].key, false);
            require(
                resolved == contracts[i].addr,
                string.concat(
                    "verifyL2Registrations: ", Strings.toHexString(uint160(contracts[i].addr), 20)
                )
            );
        }
    }

    function registerL1ContractsToL2SharedResolver(L2ContractRegistry memory l2ContractRegistry)
        internal
    {
        DefaultResolver(l2ContractRegistry.sharedResolver.addr)
            .registerAddress(l1ChainId, bytes32("bridge"), l1Bridge);
        console2.log("** Registered L1 bridge to shared resolver");

        DefaultResolver(l2ContractRegistry.sharedResolver.addr)
            .registerAddress(l1ChainId, bytes32("signal_service"), l1SignalService);
        console2.log("** Registered L1 signal service to shared resolver");

        DefaultResolver(l2ContractRegistry.sharedResolver.addr)
            .registerAddress(l1ChainId, bytes32("erc20_vault"), l1ERC20Vault);
        console2.log("** Registered L1 ERC20 vault to shared resolver");

        DefaultResolver(l2ContractRegistry.sharedResolver.addr)
            .registerAddress(l1ChainId, bytes32("erc721_vault"), l1ERC721Vault);
        console2.log("** Registered L1 ERC721 vault to shared resolver");

        DefaultResolver(l2ContractRegistry.sharedResolver.addr)
            .registerAddress(l1ChainId, bytes32("erc1155_vault"), l1ERC1155Vault);
        console2.log("** Registered L1 ERC1155 vault to shared resolver");
    }

    function setupDelegateControllerAndTransferOwnership(L2ContractRegistry memory l2ContractRegistry)
        internal
    {
        address delegateControllerImpl = address(
            new DelegateController(uint64(l1ChainId), l2ContractRegistry.bridge.addr, l1Owner)
        );
        address delegateController = address(new ERC1967Proxy(delegateControllerImpl, ""));
        DelegateController(payable(delegateController)).init();

        // Log the delegate controller address to a json file
        vm.writeJson(
            vm.serializeAddress("setup", "delegate_controller", delegateController),
            string.concat(vm.projectRoot(), "/deployments/setup_l2.json")
        );

        console2.log("** Delegate controller (L2 owner):", delegateController);

        Ownable2StepUpgradeable(l2ContractRegistry.bridge.addr)
            .transferOwnership(delegateController);
        console2.log(
            "** Initiated ownership transfer of Bridge to delegate controller:", delegateController
        );

        Ownable2StepUpgradeable(l2ContractRegistry.erc20Vault.addr)
            .transferOwnership(delegateController);
        console2.log(
            "** Initiated ownership transfer of ERC20Vault to delegate controller:",
            delegateController
        );

        Ownable2StepUpgradeable(l2ContractRegistry.erc721Vault.addr)
            .transferOwnership(delegateController);
        console2.log(
            "** Initiated ownership transfer of ERC721Vault to delegate controller:",
            delegateController
        );

        Ownable2StepUpgradeable(l2ContractRegistry.erc1155Vault.addr)
            .transferOwnership(delegateController);
        console2.log(
            "** Initiated ownership transfer of ERC1155Vault to delegate controller:",
            delegateController
        );

        Ownable2StepUpgradeable(l2ContractRegistry.signalService.addr)
            .transferOwnership(delegateController);
        console2.log(
            "** Initiated ownership transfer of SignalService to delegate controller:",
            delegateController
        );

        Ownable2StepUpgradeable(l2ContractRegistry.taiko.addr).transferOwnership(delegateController);
        console2.log(
            "** Initiated ownership transfer of TaikoAnchor to delegate controller:",
            delegateController
        );

        Ownable2StepUpgradeable(l2ContractRegistry.sharedResolver.addr)
            .transferOwnership(delegateController);
        console2.log(
            "** Initiated ownership transfer of SharedResolver to delegate controller:",
            delegateController
        );
    }

    function getConstantAddress(
        string memory prefix,
        string memory suffix
    )
        public
        pure
        returns (address)
    {
        uint256 ADDRESS_LENGTH = 40;
        bytes memory prefixBytes = bytes(prefix);
        bytes memory suffixBytes = bytes(suffix);
        require(
            prefixBytes.length + suffixBytes.length <= ADDRESS_LENGTH, "Prefix + suffix too long"
        );
        uint256 paddingLength = ADDRESS_LENGTH - prefixBytes.length - suffixBytes.length;
        bytes memory padding = new bytes(paddingLength);
        for (uint256 i = 0; i < paddingLength; i++) {
            padding[i] = "0";
        }
        string memory hexString = string(abi.encodePacked("0x", prefix, string(padding), suffix));
        return vm.parseAddress(hexString);
    }
}
