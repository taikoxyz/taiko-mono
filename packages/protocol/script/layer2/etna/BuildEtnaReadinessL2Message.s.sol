// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import { LibRebuiltCode } from "script/shared/LibRebuiltCode.sol";
import { EtnaSignalServiceUpgradeGuard } from "src/layer2/etna/EtnaSignalServiceUpgradeGuard.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

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
    /// guard.checkAfterUpgrade(proxy, etnaImpl, etnaImplCodeHash)]`.
    /// @param _guard The deployed `EtnaSignalServiceUpgradeGuard`.
    /// @param _signalService The L2 `SignalService` proxy.
    /// @param _preEtnaImpl The implementation the proxy uses before the message.
    /// @param _etnaImpl The Etna L2 `SignalService` implementation: `_authorizedSyncer` the `Anchor`
    /// proxy and `usesBeaconRoots` true.
    /// @param _etnaImplCodeHash `keccak256` of `_etnaImpl`'s runtime code.
    /// @return actions_ The three actions, in execution order.
    function buildActions(
        address _guard,
        address _signalService,
        address _preEtnaImpl,
        address _etnaImpl,
        bytes32 _etnaImplCodeHash
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
                EtnaSignalServiceUpgradeGuard.checkAfterUpgrade,
                (_signalService, _etnaImpl, _etnaImplCodeHash)
            )
        });
    }
}

/// @title BuildEtnaReadinessL2Message
/// @notice Logs the readiness proposal's L2 message actions and their `abi.encode`, the bytes that
/// `DelegateController.dryrun` takes and that follow the 8-byte execution ID in
/// `onMessageInvocation`, after checking every input against L2. It broadcasts nothing; the
/// reference contracts its checks create exist only in the script's local EVM. Run it against
/// the L2 with the `layer2` profile.
///
/// Required environment variables:
/// - UPGRADE_GUARD: the deployed `EtnaSignalServiceUpgradeGuard`, exactly this build's code
/// - L2_SIGNAL_SERVICE: the L2 `SignalService` proxy
/// - PRE_ETNA_SIGNAL_SERVICE_IMPL: the proxy's current implementation
/// - ETNA_SIGNAL_SERVICE_IMPL: the implementation `DeployShastaL2Contracts` deployed
/// - ANCHOR_PROXY: the `Anchor` proxy, whose checkpoint store is L2_SIGNAL_SERVICE
/// - L1_SIGNAL_SERVICE: the L1 `SignalService` proxy
/// ETNA_SIGNAL_SERVICE_IMPL must hold exactly this build's `SignalService` constructed as
/// `DeployShastaL2Contracts` does: syncer ANCHOR_PROXY, remote L1_SIGNAL_SERVICE, the live
/// proxy's pauser and `usesBeaconRoots` true. The syncer and remote have no getters, so its runtime
/// code is compared with a reference built from those arguments, and the message's postcondition
/// pins the code hash on chain.
/// @custom:security-contact security@taiko.xyz
contract BuildEtnaReadinessL2Message is Script {
    /// @notice The message's inputs.
    struct Inputs {
        /// @notice The deployed `EtnaSignalServiceUpgradeGuard`.
        address guard;
        /// @notice The L2 `SignalService` proxy.
        address signalService;
        /// @notice The proxy's current implementation.
        address preEtnaImpl;
        /// @notice The Etna L2 `SignalService` implementation.
        address etnaImpl;
        /// @notice The `Anchor` proxy, the implementation's expected syncer.
        address anchor;
        /// @notice The L1 `SignalService` proxy, the implementation's expected remote.
        address l1SignalService;
    }

    function run() external {
        Inputs memory inputs = Inputs({
            guard: vm.envAddress("UPGRADE_GUARD"),
            signalService: vm.envAddress("L2_SIGNAL_SERVICE"),
            preEtnaImpl: vm.envAddress("PRE_ETNA_SIGNAL_SERVICE_IMPL"),
            etnaImpl: vm.envAddress("ETNA_SIGNAL_SERVICE_IMPL"),
            anchor: vm.envAddress("ANCHOR_PROXY"),
            l1SignalService: vm.envAddress("L1_SIGNAL_SERVICE")
        });
        Controller.Action[] memory actions = buildChecked(inputs);
        for (uint256 i; i < actions.length; ++i) {
            console2.log("action", i);
            console2.log("  target:", actions[i].target);
            console2.log("  value:", actions[i].value);
            console2.log("  data:", vm.toString(actions[i].data));
        }
        console2.log("abi.encode(actions):", vm.toString(abi.encode(actions)));
    }

    /// @notice Checks `_inputs` against the current chain and returns the message's actions.
    /// @param _inputs The message's inputs.
    /// @return actions_ The three actions, in execution order.
    function buildChecked(Inputs memory _inputs)
        public
        returns (Controller.Action[] memory actions_)
    {
        require(
            LibRebuiltCode.matches(_inputs.guard, address(new EtnaSignalServiceUpgradeGuard())),
            UpgradeGuardMismatch()
        );
        require(
            _inputs.signalService.code.length != 0
                && EssentialContract(_inputs.signalService).impl() == _inputs.preEtnaImpl,
            PreEtnaImplementationMismatch()
        );
        require(
            _inputs.anchor.code.length != 0
                && _readWord(_inputs.anchor, "checkpointStore()")
                    == uint256(uint160(_inputs.signalService)),
            AnchorMismatch()
        );
        require(_inputs.l1SignalService != address(0), SignalServiceImplementationMismatch());
        address expected = address(
            new SignalService(
                _inputs.anchor, _inputs.l1SignalService, _readPauser(_inputs.signalService), true
            )
        );
        require(
            _inputs.etnaImpl != _inputs.preEtnaImpl
                && LibRebuiltCode.matches(_inputs.etnaImpl, expected),
            SignalServiceImplementationMismatch()
        );
        actions_ = LibEtnaReadinessL2Message.buildActions(
            _inputs.guard,
            _inputs.signalService,
            _inputs.preEtnaImpl,
            _inputs.etnaImpl,
            _inputs.etnaImpl.codehash
        );
    }

    /// @dev Reads the live proxy's extra pause authority, as `DeployShastaL2Contracts` does: zero
    /// for an unversioned implementation without the getter.
    /// @param _signalService The L2 `SignalService` proxy.
    /// @return pauser_ The pauser.
    function _readPauser(address _signalService) private view returns (address pauser_) {
        (bool ok, bytes memory ret) = _signalService.staticcall(abi.encodeWithSignature("pauser()"));
        if (ret.length == 0) {
            (, bytes memory version) =
                _signalService.staticcall(abi.encodeWithSignature("VERSION()"));
            require(version.length == 0, SignalServiceImplementationMismatch());
            return address(0);
        }
        require(ok && ret.length == 32, SignalServiceImplementationMismatch());
        return abi.decode(ret, (address));
    }

    /// @dev Reads one 32-byte word from a getter.
    /// @param _target The contract.
    /// @param _signature The getter's signature.
    /// @return word_ The word, or zero if the call fails or returns another length.
    function _readWord(
        address _target,
        string memory _signature
    )
        private
        view
        returns (uint256 word_)
    {
        (bool ok, bytes memory ret) = _target.staticcall(abi.encodeWithSignature(_signature));
        if (ok && ret.length == 32) word_ = abi.decode(ret, (uint256));
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error AnchorMismatch();
    error PreEtnaImplementationMismatch();
    error SignalServiceImplementationMismatch();
    error UpgradeGuardMismatch();
}
