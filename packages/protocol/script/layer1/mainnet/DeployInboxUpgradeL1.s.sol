// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";

/// @title DeployInboxUpgradeL1
/// @notice Deploys the `MainnetInbox` implementation that Proposal0024 upgrades the mainnet inbox
/// proxy to: the live configuration with `basefeeSharingPctg` raised from 75 to 100.
/// @dev Deploys a new implementation only. It does not upgrade the proxy and does not call any
/// initializer.
///
/// The five constructor arguments reproduce the address immutables the live implementation
/// (`0x5253D4C91e80b880DdB54B78E74082Abe066F6b9`, deployed for Proposal0019) carries, and the
/// script reads them back from the live proxy before broadcasting so a drifted `LibL1Addrs`
/// constant aborts the run instead of baking into the new immutables. The numeric configuration is
/// hardcoded in `MainnetInbox`, so after deploying, the script compares the new implementation's
/// `getConfig()` with the live proxy's and aborts unless the basefee sharing percentage is the
/// only difference.
///
/// Diffing the implementation's dependency tree from the commit the live implementation was built
/// from (`9078278909a43a83fc5bb2664f30b81eb5c967f6`) to `main` leaves `MainnetInbox.sol` and
/// `EssentialContract.sol`: #22058 folded the transient-storage reentry lock `MainnetInbox`
/// already used through `LibFasterReentryLock` into the base contract at the same slot constant.
/// So the only behavioural change this implementation ships is the sharing percentage.
///
/// `MainnetInbox` links `LibForcedInclusion` and `LibInboxSetup` (both have `public` functions),
/// so the broadcast is three creates: the two libraries through CREATE2, then the implementation.
/// Verify all three landed before writing the logged address anywhere.
/// @custom:security-contact security@taiko.xyz
contract DeployInboxUpgradeL1 is Script {
    /// @notice The basefee sharing percentage the new implementation must carry.
    uint8 public constant NEW_BASEFEE_SHARING_PCTG = 100;

    error AlreadyUpgraded();
    error ConfigMismatch();
    error LiveProxyMismatch();

    /// @notice Deploys the implementation and logs the address Proposal0024 needs.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        IInbox.Config memory live = IInbox(LibL1Addrs.INBOX).getConfig();
        _checkLiveProxy(live);

        vm.startBroadcast(privateKey);
        MainnetInbox inboxImpl = new MainnetInbox(
            LibL1Addrs.ZK_REQUIRED_VERIFIER,
            LibL1Addrs.PRECONF_WHITELIST,
            LibL1Addrs.PROVER_WHITELIST,
            LibL1Addrs.SIGNAL_SERVICE,
            LibL1Addrs.TAIKO_TOKEN
        );
        vm.stopBroadcast();

        _checkConfig(inboxImpl.getConfig(), live);

        console2.log("MAINNET_INBOX_NEW_IMPL:", address(inboxImpl));
    }

    /// @dev Aborts unless the live proxy answers the five addresses this script is about to
    /// compile into the new implementation — all five are reproduced from `LibL1Addrs`, and the
    /// whole point of the upgrade is to keep them — and still shares the old percentage, so the
    /// script cannot be re-run to any effect once the proposal has executed.
    /// @param _live The live proxy's configuration.
    function _checkLiveProxy(IInbox.Config memory _live) private pure {
        require(
            _live.proofVerifier == LibL1Addrs.ZK_REQUIRED_VERIFIER
                && _live.proposerChecker == LibL1Addrs.PRECONF_WHITELIST
                && _live.proverWhitelist == LibL1Addrs.PROVER_WHITELIST
                && _live.signalService == LibL1Addrs.SIGNAL_SERVICE
                && _live.bondToken == LibL1Addrs.TAIKO_TOKEN,
            LiveProxyMismatch()
        );
        require(_live.basefeeSharingPctg != NEW_BASEFEE_SHARING_PCTG, AlreadyUpgraded());
    }

    /// @dev Aborts unless the new implementation's configuration equals the live one in every
    /// field but the basefee sharing percentage, which must be the new value. Catches a
    /// transposed constructor argument (all five are addresses, so a swapped pair compiles
    /// cleanly) and any numeric constant in `MainnetInbox` that drifted from the live value.
    /// @param _new The freshly deployed implementation's configuration.
    /// @param _live The live proxy's configuration.
    function _checkConfig(
        IInbox.Config memory _new,
        IInbox.Config memory _live
    )
        private
        pure
    {
        require(_new.basefeeSharingPctg == NEW_BASEFEE_SHARING_PCTG, ConfigMismatch());

        // Normalise the one field that is meant to differ, then compare the rest in one go. `_new`
        // is the caller's own copy, so overwriting it here is local to this check.
        _new.basefeeSharingPctg = _live.basefeeSharingPctg;
        require(keccak256(abi.encode(_new)) == keccak256(abi.encode(_live)), ConfigMismatch());
    }
}
