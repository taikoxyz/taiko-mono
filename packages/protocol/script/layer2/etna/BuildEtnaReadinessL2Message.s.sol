// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import { EtnaSignalServiceUpgradeGuard } from "src/layer2/etna/EtnaSignalServiceUpgradeGuard.sol";
import { Controller } from "src/shared/governance/Controller.sol";

/// @title LibEtnaReadinessL2Message
/// @notice Builds the actions of the readiness proposal's one L2 message to the
/// `DelegateController` (Etna SWITCH.md section 3, ANCHORLESS.md section 8, step 3).
/// @dev The message upgrades only the L2 `SignalService` proxy, between a precondition and a
/// postcondition of the deployed `EtnaSignalServiceUpgradeGuard`. It carries no deadline and no fork
/// time, so it can execute in any block before Etna and moving the schedule never touches it. A
/// proposal returns these actions from `BuildProposal.buildL2Actions`; execution ID 0 has no next-ID
/// dependency, so a failed invocation can be retried (SWITCH.md section 7).
/// @custom:security-contact security@taiko.xyz
library LibEtnaReadinessL2Message {
    /// @dev Returns `[guard.checkBeforeUpgrade(proxy, preEtnaImpl), proxy.upgradeTo(etnaImpl),
    /// guard.checkAfterUpgrade(proxy, etnaImpl)]`.
    /// @param _guard The deployed `EtnaSignalServiceUpgradeGuard`.
    /// @param _signalService The L2 `SignalService` proxy.
    /// @param _preEtnaImpl The implementation the proxy uses before the message.
    /// @param _etnaImpl The Etna L2 `SignalService` implementation: `_authorizedSyncer` the `Anchor`
    /// proxy and `usesBeaconRoots` true.
    /// @return actions_ The three actions, in execution order.
    function buildActions(
        address _guard,
        address _signalService,
        address _preEtnaImpl,
        address _etnaImpl
    )
        internal
        pure
        returns (Controller.Action[] memory actions_)
    {
        actions_ = new Controller.Action[](3);
        actions_[0] = Controller.Action({
            target: _guard,
            value: 0,
            data: abi.encodeCall(
                EtnaSignalServiceUpgradeGuard.checkBeforeUpgrade, (_signalService, _preEtnaImpl)
            )
        });
        actions_[1] = Controller.Action({
            target: _signalService,
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (_etnaImpl))
        });
        actions_[2] = Controller.Action({
            target: _guard,
            value: 0,
            data: abi.encodeCall(
                EtnaSignalServiceUpgradeGuard.checkAfterUpgrade, (_signalService, _etnaImpl)
            )
        });
    }
}

/// @title BuildEtnaReadinessL2Message
/// @notice Logs the readiness proposal's L2 message actions and their `abi.encode`, the bytes that
/// `DelegateController.dryrun` takes and that follow the 8-byte execution ID in
/// `onMessageInvocation`. It reads, broadcasts and checks nothing on chain.
///
/// Required environment variables:
/// - UPGRADE_GUARD: the deployed `EtnaSignalServiceUpgradeGuard`
/// - L2_SIGNAL_SERVICE: the L2 `SignalService` proxy
/// - PRE_ETNA_SIGNAL_SERVICE_IMPL: the proxy's implementation before the message
/// - ETNA_SIGNAL_SERVICE_IMPL: the implementation `DeployShastaL2Contracts` deployed
/// @custom:security-contact security@taiko.xyz
contract BuildEtnaReadinessL2Message is Script {
    function run() external view {
        address guard = vm.envAddress("UPGRADE_GUARD");
        address signalService = vm.envAddress("L2_SIGNAL_SERVICE");
        address preEtnaImpl = vm.envAddress("PRE_ETNA_SIGNAL_SERVICE_IMPL");
        address etnaImpl = vm.envAddress("ETNA_SIGNAL_SERVICE_IMPL");
        require(guard != address(0), "UPGRADE_GUARD not set");
        require(signalService != address(0), "L2_SIGNAL_SERVICE not set");
        require(preEtnaImpl != address(0), "PRE_ETNA_SIGNAL_SERVICE_IMPL not set");
        require(etnaImpl != address(0), "ETNA_SIGNAL_SERVICE_IMPL not set");
        require(preEtnaImpl != etnaImpl, "Implementations are equal");

        Controller.Action[] memory actions =
            LibEtnaReadinessL2Message.buildActions(guard, signalService, preEtnaImpl, etnaImpl);
        for (uint256 i; i < actions.length; ++i) {
            console2.log("action", i);
            console2.log("  target:", actions[i].target);
            console2.log("  value:", actions[i].value);
            console2.log("  data:", vm.toString(actions[i].data));
        }
        console2.log("abi.encode(actions):", vm.toString(abi.encode(actions)));
    }
}
