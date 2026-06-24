// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Script} from "forge-std/src/Script.sol";
import {console2} from "forge-std/src/console2.sol";
import {IInbox} from "src/layer1/core/iface/IInbox.sol";
import {DevnetInbox} from "src/layer1/devnet/DevnetInbox.sol";

/// @title UpgradeInboxToDevnetInbox
/// @notice Deploys a DevnetInbox implementation and upgrades the configured Inbox proxy to it.
/// @custom:security-contact security@taiko.xyz
contract UpgradeInboxToDevnetInbox is Script {
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
        address inboxProxy = vm.envAddress("INBOX_PROXY");
        _validateContract("INBOX_PROXY", inboxProxy);

        IInbox.Config memory config = IInbox(inboxProxy).getConfig();
        address inboxImpl = address(
            new DevnetInbox(
                config.proofVerifier,
                config.proposerChecker,
                config.proverWhitelist,
                config.signalService,
                config.bondToken
            )
        );

        console2.log("INBOX_PROXY=", inboxProxy);
        console2.log("DEVNET_INBOX_IMPL=", inboxImpl);
        console2.log("PROOF_VERIFIER=", config.proofVerifier);
        console2.log("PROPOSER_CHECKER=", config.proposerChecker);
        console2.log("PROVER_WHITELIST=", config.proverWhitelist);
        console2.log("SIGNAL_SERVICE=", config.signalService);
        console2.log("BOND_TOKEN=", config.bondToken);

        UUPSUpgradeable(inboxProxy).upgradeTo(inboxImpl);
        console2.log("Inbox upgraded to DevnetInbox");
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    function _validateContract(string memory _name, address _addr) private view {
        if (_addr == address(0)) revert AddressIsZero(_name);
        if (_addr.code.length == 0) revert ContractHasNoCode(_name, _addr);
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidPrivateKey();
    error AddressIsZero(string name);
    error ContractHasNoCode(string name, address addr);
}
