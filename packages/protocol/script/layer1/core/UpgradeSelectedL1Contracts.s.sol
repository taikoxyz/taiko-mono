// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Script} from "forge-std/src/Script.sol";
import {console2} from "forge-std/src/console2.sol";

/// @title UpgradeSelectedL1Contracts
/// @notice Upgrades only SignalService, Bridge, ERC20Vault, and Inbox.
/// @custom:security-contact security@taiko.xyz
contract UpgradeSelectedL1Contracts is Script {
    struct UpgradeConfig {
        address signalServiceProxy;
        address signalServiceImpl;
        address bridgeProxy;
        address bridgeImpl;
        address erc20VaultProxy;
        address erc20VaultImpl;
        address inboxProxy;
        address inboxImpl;
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
        config_.signalServiceImpl = vm.envAddress("SIGNAL_SERVICE_IMPL");
        config_.bridgeProxy = vm.envAddress("BRIDGE_PROXY");
        config_.bridgeImpl = vm.envAddress("BRIDGE_IMPL");
        config_.erc20VaultProxy = vm.envAddress("ERC20_VAULT_PROXY");
        config_.erc20VaultImpl = vm.envAddress("ERC20_VAULT_IMPL");
        config_.inboxProxy = vm.envAddress("INBOX_PROXY");
        config_.inboxImpl = vm.envAddress("INBOX_IMPL");
    }

    function _validateConfig(UpgradeConfig memory _config) private view {
        _validateAddress("SIGNAL_SERVICE_PROXY", _config.signalServiceProxy);
        _validateImplementation("SIGNAL_SERVICE_IMPL", _config.signalServiceImpl);
        _validateAddress("BRIDGE_PROXY", _config.bridgeProxy);
        _validateImplementation("BRIDGE_IMPL", _config.bridgeImpl);
        _validateAddress("ERC20_VAULT_PROXY", _config.erc20VaultProxy);
        _validateImplementation("ERC20_VAULT_IMPL", _config.erc20VaultImpl);
        _validateAddress("INBOX_PROXY", _config.inboxProxy);
        _validateImplementation("INBOX_IMPL", _config.inboxImpl);
    }

    function _upgrade(UpgradeConfig memory _config) private {
        _upgradeTo("SignalService", _config.signalServiceProxy, _config.signalServiceImpl);
        _upgradeTo("Bridge", _config.bridgeProxy, _config.bridgeImpl);
        _upgradeTo("ERC20Vault", _config.erc20VaultProxy, _config.erc20VaultImpl);
        _upgradeTo("Inbox", _config.inboxProxy, _config.inboxImpl);
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

    function _validateImplementation(string memory _name, address _impl) private view {
        _validateAddress(_name, _impl);
        if (_impl.code.length == 0) revert ImplementationHasNoCode(_name, _impl);
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidPrivateKey();
    error AddressIsZero(string name);
    error ImplementationHasNoCode(string name, address impl);
}
