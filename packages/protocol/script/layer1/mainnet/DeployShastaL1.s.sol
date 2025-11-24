// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";

import { CodecOptimized } from "src/layer1/core/impl/CodecOptimized.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { PreconfWhitelist } from "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { SignalServiceForkRouter } from "src/shared/signal/SignalServiceForkRouter.sol";

/// FOUNDRY_PROFILE=layer1 forge script --rpc-url <L1_RPC> script/layer1/mainnet/DeployShastaL1.s.sol --broadcast
/// Deploys a CodecOptimized, SignalService fork router, and a new Shasta Inbox.
contract DeployShastaL1 is BaseScript {
    struct Config {
        address proofVerifier;
        address proposerChecker;
        address taikoAdmin;
        address remoteSignalService;
        address oldSignalServiceImpl;
        uint64 shastaForkTimestamp;
    }

    /// @dev Loads config from env vars.
    function _loadConfig() private view returns (Config memory c) {
        c.proofVerifier = vm.envAddress("PROOF_VERIFIER"); // Will be deployed in a separated script, should be 100% zk.
        c.proposerChecker = 0xFD019460881e6EeC632258222393d5821029b2ac; // preconf_whitelist
        c.taikoAdmin = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F; // admin.taiko.eth
        c.remoteSignalService = LibL2Addrs.SIGNAL_SERVICE;
        c.oldSignalServiceImpl = SignalService(LibL1Addrs.SIGNAL_SERVICE).impl();
        c.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
    }

    function run() external broadcast {
        Config memory c = _loadConfig();

        address inboxProxy = _deployInbox(c);
        _deploySignalServiceFork(c, inboxProxy);
        deployPreconfWhitelistImpl();
    }

    /// @dev Deploys a PreconfWhitelist implementation (no proxy).
    function deployPreconfWhitelistImpl() private {
        address impl = address(new PreconfWhitelist());
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
        CodecOptimized codec = new CodecOptimized();
        MainnetInbox impl = new MainnetInbox(address(codec), c.proofVerifier, c.proposerChecker);
        proxy = deploy({
            name: "shasta_inbox",
            impl: address(impl),
            // NOTE: we need to let `admin.taiko.eth` to transfer the ownership of shasta inbox to
            // DAO later after the shasta genesis proposal initialization, then create another
            // proposal to let the DAO accept the ownership.
            data: abi.encodeCall(Inbox.init, (c.taikoAdmin))
        });

        console2.log("Inbox proxy deployed:", proxy);
        console2.log("CodecOptimized implementation:", address(codec));
        console2.log("Inbox implementation:", address(impl));
    }
}
