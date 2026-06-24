// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Script} from "forge-std/src/Script.sol";
import {console2} from "forge-std/src/console2.sol";
import {IInbox} from "src/layer1/core/iface/IInbox.sol";
import {DevnetInbox} from "src/layer1/devnet/DevnetInbox.sol";
import {MainnetBridge} from "src/layer1/mainnet/MainnetBridge.sol";
import {MainnetERC20Vault} from "src/layer1/mainnet/MainnetERC20Vault.sol";
import {SignalService} from "src/shared/signal/SignalService.sol";

/// @title UpgradeSelectedL1Contracts
/// @notice Deploys implementations and upgrades only SignalService, Bridge, ERC20Vault, and Inbox.
/// @custom:security-contact security@taiko.xyz
contract UpgradeSelectedL1Contracts is Script {
    struct UpgradeConfig {
        address signalServiceProxy;
        address l2SignalService;
        address signalServicePauser;
        address bridgeProxy;
        address sharedResolver;
        address quotaManager;
        address bridgePauser;
        address erc20VaultProxy;
        address inboxProxy;
    }

    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        if (privateKey == 0) revert InvalidPrivateKey();
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    function run() external broadcast {
        UpgradeConfig memory config = _loadConfig();
        _validateConfig(config);
        _upgrade(config);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    function _loadConfig() private view returns (UpgradeConfig memory config_) {
        config_.signalServiceProxy = vm.envAddress("SIGNAL_SERVICE_PROXY");
        config_.l2SignalService = vm.envAddress("L2_SIGNAL_SERVICE_PROXY");
        config_.signalServicePauser = vm.envOr("SIGNAL_SERVICE_PAUSER", address(0));
        config_.bridgeProxy = vm.envAddress("BRIDGE_PROXY");
        config_.sharedResolver = vm.envAddress("SHARED_RESOLVER");
        config_.quotaManager = vm.envOr("QUOTA_MANAGER", address(0));
        config_.bridgePauser = vm.envOr("BRIDGE_PAUSER", address(0));
        config_.erc20VaultProxy = vm.envAddress("ERC20_VAULT_PROXY");
        config_.inboxProxy = vm.envAddress("INBOX_PROXY");
    }

    function _validateConfig(UpgradeConfig memory _config) private view {
        _validateContract("SIGNAL_SERVICE_PROXY", _config.signalServiceProxy);
        _validateAddress("L2_SIGNAL_SERVICE_PROXY", _config.l2SignalService);
        _validateContract("BRIDGE_PROXY", _config.bridgeProxy);
        _validateContract("SHARED_RESOLVER", _config.sharedResolver);
        _validateOptionalContract("QUOTA_MANAGER", _config.quotaManager);
        _validateContract("ERC20_VAULT_PROXY", _config.erc20VaultProxy);
        _validateContract("INBOX_PROXY", _config.inboxProxy);
    }

    function _upgrade(UpgradeConfig memory _config) private {
        address signalServiceImpl =
            address(new SignalService(_config.inboxProxy, _config.l2SignalService, _config.signalServicePauser));
        _upgradeTo("SignalService", _config.signalServiceProxy, signalServiceImpl);

        address bridgeImpl = address(
            new MainnetBridge(
                _config.sharedResolver, _config.signalServiceProxy, _config.quotaManager, _config.bridgePauser
            )
        );
        _upgradeTo("Bridge", _config.bridgeProxy, bridgeImpl);

        address erc20VaultImpl = address(new MainnetERC20Vault(_config.sharedResolver, _config.quotaManager));
        _upgradeTo("ERC20Vault", _config.erc20VaultProxy, erc20VaultImpl);

        IInbox.Config memory inboxConfig = IInbox(_config.inboxProxy).getConfig();
        address inboxImpl = address(
            new DevnetInbox(
                inboxConfig.proofVerifier,
                inboxConfig.proposerChecker,
                inboxConfig.proverWhitelist,
                inboxConfig.signalService,
                inboxConfig.bondToken
            )
        );
        _upgradeTo("Inbox", _config.inboxProxy, inboxImpl);
    }

    function _upgradeTo(string memory _name, address _proxy, address _impl) private {
        console2.log(string.concat(_name, "_PROXY="), _proxy);
        console2.log(string.concat(_name, "_IMPL="), _impl);
        UUPSUpgradeable(_proxy).upgradeTo(_impl);
        console2.log(string.concat(_name, " upgraded"));
    }

    function _validateAddress(string memory _name, address _addr) private pure {
        if (_addr == address(0)) revert AddressIsZero(_name);
    }

    function _validateContract(string memory _name, address _addr) private view {
        _validateAddress(_name, _addr);
        if (_addr.code.length == 0) revert ContractHasNoCode(_name, _addr);
    }

    function _validateOptionalContract(string memory _name, address _addr) private view {
        if (_addr != address(0) && _addr.code.length == 0) revert ContractHasNoCode(_name, _addr);
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidPrivateKey();
    error AddressIsZero(string name);
    error ContractHasNoCode(string name, address addr);
}
