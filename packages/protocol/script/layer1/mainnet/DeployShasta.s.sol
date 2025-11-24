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

/// @title DeployShasta
/// @notice This deployment script deploys the following contracts:
/// - CodecOptimized (L1 codec used by the inbox)
/// - MainnetInbox (implementation for Shasta Inbox, behind proxy)
/// - Proxy for the Shasta Inbox
/// - SignalService implementation (for Shasta fork)
/// - SignalServiceForkRouter (routes to old vs new SignalService at the fork timestamp)
/// - PreconfWhitelist (new implementation, no proxy)
///
/// FOUNDRY_PROFILE=layer1 forge script --rpc-url <L1_RPC> script/layer1/mainnet/DeployShasta.s.sol --broadcast
contract DeployShasta is BaseScript {
    struct Config {
        address proofVerifier;
        address proposerChecker;
        address taikoAdmin;
        address remoteSignalService;
        address signalServiceOldImpl;
        uint64 shastaForkTimestamp;
    }

    /// @dev Loads config from env vars.
    function _loadConfig() private view returns (Config memory c) {
        // proofVerifier will be deployed in a separated script, should be 100% zk.
        c.proofVerifier = vm.envAddress("PROOF_VERIFIER");
        require(c.proofVerifier != address(0), "PROOF_VERIFIER not set");
        console2.log("proofVerifier:", c.proofVerifier);

        c.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
        require(c.shastaForkTimestamp != 0, "SHASTA_FORK_TIMESTAMP not set");
        console2.log("shastaForkTimestamp:", c.shastaForkTimestamp);

        c.proposerChecker = LibL1Addrs.PRECONF_WHITELIST;
        console2.log("proposerChecker (preconfWhitelist):", c.proposerChecker);

        c.taikoAdmin = LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH;
        console2.log("taikoAdmin:", c.taikoAdmin);

        c.remoteSignalService = LibL2Addrs.SIGNAL_SERVICE;
        console2.log("remoteSignalService:", c.remoteSignalService);

        c.signalServiceOldImpl = SignalService(LibL1Addrs.SIGNAL_SERVICE).impl();
        console2.log("signalServiceOldImpl:", c.signalServiceOldImpl);
    }

    function run() external broadcast {
        Config memory config = _loadConfig();

        address inboxProxy = _deployInbox(config);
        _deploySignalServiceFork(config, inboxProxy);
        _deployPreconfWhitelistImpl();
    }

    /// @dev Deploys a PreconfWhitelist implementation (no proxy).
    function _deployPreconfWhitelistImpl() private {
        address preconfWhitelistNewImpl = address(new PreconfWhitelist());
        console2.log("preconfWhitelistNewImpl deployed:", preconfWhitelistNewImpl);
    }

    /// @dev Deploys SignalService implementation and fork router, initializes router storage.
    function _deploySignalServiceFork(Config memory config, address inboxProxy) private {
        address signalServiceNewImpl =
            address(new SignalService(inboxProxy, config.remoteSignalService));
        address signalServiceForkRouter = address(
            new SignalServiceForkRouter(
                config.signalServiceOldImpl, signalServiceNewImpl, config.shastaForkTimestamp
            )
        );

        console2.log("signalServiceNewImpl deployed:", signalServiceNewImpl);
        console2.log("signalServiceForkRouter deployed:", signalServiceForkRouter);
    }

    /// @dev Deploys MainnetInbox.
    function _deployInbox(Config memory config) private returns (address mainnetInboxProxy) {
        address codec = address(new CodecOptimized());
        console2.log("CodecOptimized deployed:", codec);

        address mainnetInboxImpl =
            address(new MainnetInbox(codec, config.proofVerifier, config.proposerChecker));
        console2.log("mainnetInboxImpl deploeyd:", mainnetInboxImpl);

        mainnetInboxProxy = deploy({
            name: "shasta_inbox",
            impl: mainnetInboxImpl,
            // NOTE: we need to let `admin.taiko.eth` to transfer the ownership of shasta inbox to
            // DAO later after the shasta genesis proposal initialization.
            // Later the DAO can accept the ownership without another proposal -- acceptOwnershipOf() is permissionless.
            data: abi.encodeCall(Inbox.init, (config.taikoAdmin))
        });

        console2.log("mainnetInboxProxy deployed:", mainnetInboxProxy);
        console2.log("mainnetInboxProxy owner():", MainnetInbox(mainnetInboxProxy).owner());
    }
}
