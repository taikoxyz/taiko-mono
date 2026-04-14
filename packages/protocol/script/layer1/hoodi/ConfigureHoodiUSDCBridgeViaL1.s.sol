// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

import { LibL1HoodiAddrs } from "src/layer1/hoodi/LibL1HoodiAddrs.sol";
import { LibL2HoodiAddrs } from "src/layer2/hoodi/LibL2HoodiAddrs.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";

/// @title ConfigureHoodiUSDCBridgeViaL1
/// @notice Sends the Hoodi L1 bridge message that instructs the L2 delegate controller to
/// register native USDC in the Taiko Hoodi ERC20 vault.
/// @dev This is the live execution path for Hoodi because the L2 ERC20 vault owner is the L2
/// delegate controller, whose L1 daoController is the Hoodi contract-owner EOA.
/// @custom:security-contact security@taiko.xyz
contract ConfigureHoodiUSDCBridgeViaL1 is Script {
    struct Config {
        address l1Bridge;
        address l2DelegateController;
        address l2Erc20Vault;
        address l1UsdcToken;
        address l2UsdcToken;
        uint64 srcChainId;
        uint64 destChainId;
        uint64 executionId;
        uint32 gasLimit;
    }

    uint256 internal _privateKey;

    function setUp() public {
        _privateKey = vm.envUint("PRIVATE_KEY");
    }

    function run() external returns (bytes32 msgHash_, IBridge.Message memory message_) {
        Config memory config = _loadConfig();
        address broadcaster = vm.addr(_privateKey);

        _validateConfig(config, broadcaster);

        Controller.Action[] memory actions = new Controller.Action[](1);
        actions[0] = Controller.Action({
            target: config.l2Erc20Vault,
            value: 0,
            data: abi.encodeCall(
                ERC20Vault.changeBridgedToken,
                (
                    ERC20Vault.CanonicalERC20({
                        chainId: uint64(LibNetwork.ETHEREUM_HOODI),
                        addr: config.l1UsdcToken,
                        decimals: 6,
                        symbol: "USDC",
                        name: "USD Coin"
                    }),
                    config.l2UsdcToken
                )
            )
        });

        message_ = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: config.gasLimit,
            from: broadcaster,
            srcChainId: config.srcChainId,
            srcOwner: broadcaster,
            destChainId: config.destChainId,
            destOwner: config.l2DelegateController,
            to: config.l2DelegateController,
            value: 0,
            data: abi.encodeCall(
                IMessageInvocable.onMessageInvocation,
                (abi.encodePacked(config.executionId, abi.encode(actions)))
            )
        });

        vm.startBroadcast(_privateKey);
        (msgHash_, message_) = IBridge(config.l1Bridge).sendMessage(message_);
        vm.stopBroadcast();

        console2.log("Sent Hoodi USDC bridge message hash:", uint256(msgHash_));
        console2.log("L1 bridge:", config.l1Bridge);
        console2.log("L2 delegate controller:", config.l2DelegateController);
        console2.log("L2 ERC20 vault:", config.l2Erc20Vault);
        console2.log("L1 canonical USDC:", config.l1UsdcToken);
        console2.log("L2 native USDC:", config.l2UsdcToken);
    }

    function _loadConfig() internal view returns (Config memory config) {
        config.l1Bridge = vm.envOr("L1_BRIDGE", LibL1HoodiAddrs.HOODI_BRIDGE);
        config.l2DelegateController =
            vm.envOr("DELEGATE_CONTROLLER", _delegateControllerFromVaultOwner());
        config.l2Erc20Vault = vm.envOr("ERC20_VAULT_ADDRESS", LibL2HoodiAddrs.HOODI_ERC20_VAULT);
        config.l1UsdcToken = vm.envAddress("L1_USDC_TOKEN");
        config.l2UsdcToken = vm.envAddress("L2_USDC_TOKEN");
        config.srcChainId = uint64(LibNetwork.ETHEREUM_HOODI);
        config.destChainId = LibNetwork.TAIKO_HOODI;
        config.executionId = uint64(vm.envOr("L2_EXECUTION_ID", uint256(0)));
        config.gasLimit = uint32(vm.envOr("L2_GAS_LIMIT", uint256(5_000_000)));
    }

    function _validateConfig(Config memory config, address broadcaster) internal view {
        require(broadcaster == LibL1HoodiAddrs.HOODI_CONTRACT_OWNER, "invalid hoodi owner key");
        require(config.l1Bridge != address(0), "invalid l1 bridge");
        require(config.l2DelegateController != address(0), "invalid delegate controller");
        require(config.l2Erc20Vault != address(0), "invalid erc20 vault");
        require(config.l1UsdcToken != address(0), "invalid l1 usdc");
        require(config.l2UsdcToken != address(0), "invalid l2 usdc");
        require(config.gasLimit != 0, "invalid gas limit");
        require(
            ERC20Vault(payable(config.l2Erc20Vault)).owner() == config.l2DelegateController,
            "vault owner mismatch"
        );

        // Validate the delegate controller wiring against live Hoodi configuration.
        (bool success, bytes memory result) =
            config.l2DelegateController.staticcall(abi.encodeWithSignature("l2Bridge()"));
        require(
            success && abi.decode(result, (address)) == LibL2HoodiAddrs.HOODI_BRIDGE,
            "invalid delegate controller l2 bridge"
        );

        (success, result) =
            config.l2DelegateController.staticcall(abi.encodeWithSignature("daoController()"));
        require(
            success && abi.decode(result, (address)) == broadcaster,
            "invalid delegate controller dao controller"
        );

        (success, result) =
            config.l2DelegateController.staticcall(abi.encodeWithSignature("l1ChainId()"));
        require(
            success && abi.decode(result, (uint64)) == config.srcChainId,
            "invalid delegate controller l1 chain"
        );
    }

    function _delegateControllerFromVaultOwner() internal view returns (address) {
        return ERC20Vault(payable(LibL2HoodiAddrs.HOODI_ERC20_VAULT)).owner();
    }
}
