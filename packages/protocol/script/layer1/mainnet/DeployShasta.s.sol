// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";

import { CodecOptimized } from "src/layer1/core/impl/CodecOptimized.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { PreconfWhitelist } from "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { SignalServiceForkRouter } from "src/shared/signal/SignalServiceForkRouter.sol";

/// forge script --rpc-url <L1_RPC> script/layer1/mainnet/DeployShasta.s.sol --broadcast
/// Deploys a fresh CodecOptimized, SignalService fork router, and a standalone Shasta Inbox implementation.
contract DeployShasta is BaseScript {
    struct Config {
        address proofVerifier;
        address proposerChecker;
        address owner;
        address remoteSignalService;
        address oldSignalServiceImpl;
        uint64 shastaForkTimestamp;
    }

    /// @dev Loads config from env vars.
    function _loadConfig() private view returns (Config memory c) {
        c.proofVerifier = vm.envAddress("PROOF_VERIFIER");
        c.proposerChecker = vm.envAddress("PROPOSER_CHECKER"); // 0xFD019460881e6EeC632258222393d5821029b2ac
        c.owner = vm.envAddress("OWNER"); // admin.taiko.eth
        c.remoteSignalService = vm.envAddress("REMOTE_SIGNAL_SERVICE"); // 0x1670000000000000000000000000000000000005
        c.oldSignalServiceImpl = vm.envAddress("OLD_SIGNAL_SERVICE_IMPL"); // 0x42Ec977eb6B09a8D78c6D486c3b0e63569bA851c
        c.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
    }

    function run() external broadcast {
        Config memory c = _loadConfig();

        address inboxProxy = _deployInbox(c);
        _deploySignalServiceFork(c, inboxProxy);
    }

    /// @dev Deploys a PreconfWhitelist implementation (no proxy).
    function deployPreconfWhitelistImpl() external broadcast returns (address impl) {
        impl = address(new PreconfWhitelist());
        console2.log("PreconfWhitelist implementation deployed:", impl);
    }

    /// @dev Deploys SignalService implementation and fork router, initializes router storage.
    function _deploySignalServiceFork(Config memory c, address authorizedSyncer) private {
        SignalService newSignalService = new SignalService(authorizedSyncer, c.remoteSignalService);
        SignalServiceForkRouter router = new SignalServiceForkRouter(
            c.oldSignalServiceImpl, address(newSignalService), c.shastaForkTimestamp
        );

        console2.log("SignalService implementation deployed:", address(newSignalService));
        console2.log("SignalService fork router deployed:", address(router));
    }

    /// @dev Deploys MainnetInbox.
    function _deployInbox(Config memory c) private returns (address proxy) {
        MainnetInbox impl =
            new MainnetInbox(address(new CodecOptimized()), c.proofVerifier, c.proposerChecker);
        proxy = deploy({
            name: "shasta_inbox",
            impl: address(impl),
            data: abi.encodeCall(Inbox.init, (c.owner))
        });

        console2.log("Inbox proxy deployed:", proxy);
        console2.log("Inbox implementation:", address(impl));
    }
}
