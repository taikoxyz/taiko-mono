// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployEtnaDevnet } from "./DeployEtnaDevnet.s.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { console2 } from "forge-std/src/Script.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxWithEtnaCutoffs } from "src/layer1/core/impl/InboxWithEtnaCutoffs.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EtnaSwitchGuard } from "src/layer1/etna/switch/EtnaSwitchGuard.sol";
import { ComposeVerifier } from "src/layer1/verifiers/compose/ComposeVerifier.sol";
import { ZkRequiredVerifier } from "src/layer1/verifiers/compose/ZkRequiredVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @notice Chain identity shared by the SGX, RISC0 and SP1 sub-verifiers.
/// @custom:security-contact security@taiko.xyz
interface IEtnaVerifierIdentity {
    /// @notice Returns the L2 chain whose proofs this verifier accepts.
    /// @return The L2 chain identifier.
    function taikoChainId() external view returns (uint64);
}

/// @title DeployEtnaSwitch
/// @notice Prepares contracts for switching a live Unzen chain to Etna, without upgrading proxies.
/// @dev Reuses the new-network registry and initialization parameters. Additional environment:
/// UNZEN_INBOX, SIGNAL_SERVICE (the existing L1 proxy), ETNA_FORK_TIME, PROPOSE_MARGIN and
/// FI_MARGIN. Export the deployed cutoff implementation as UNZEN_INBOX_IMPLEMENTATION before
/// deployInbox. REMOTE_SIGNAL_SERVICE is the existing L2 proxy. GENESIS_BLOCK_HASH and
/// GENESIS_STATE_ROOT are not read: the start remains unwritten until anyone calls `setOrigin`.
/// Deploy the bootstrap, then its registry, dedicated verifiers, the three implementations and
/// the switch guard. Every deployment entry point only creates contracts; the DAO batches that
/// install them are built by `BuildEtnaSwitchProposals`, and `setOrigin` is permissionless. The
/// live Unzen Inbox may be in either switch state (Etna SWITCH.md section 3): before the
/// scheduling proposal executes it saves checkpoints in SIGNAL_SERVICE, after it through
/// INBOX_PROXY, as when a postponement is prepared. Once the Etna Inbox is initialized, a new
/// ETNA_FORK_TIME must be later than its installed one (SWITCH.md section 7).
/// @custom:security-contact security@taiko.xyz
contract DeployEtnaSwitch is DeployEtnaDevnet {
    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Deploys only the Etna bootstrap proxy, retaining the existing L1 SignalService.
    /// @return proxy_ New Etna Inbox proxy.
    /// @return signalService_ Existing L1 SignalService proxy; never replaced or initialized.
    function deployInboxProxy() external override returns (address proxy_, address signalService_) {
        _liveUnzenConfig();
        uint256 key = _privateKey();
        address owner = _owner(key);
        signalService_ = vm.envAddress("SIGNAL_SERVICE");
        vm.startBroadcast(key);
        proxy_ = address(
            new ERC1967Proxy(
                address(new EtnaInboxBootstrap()), abi.encodeCall(EtnaInboxBootstrap.init, (owner))
            )
        );
        vm.stopBroadcast();
        console2.log("Etna Inbox bootstrap proxy:", proxy_);
        console2.log("Retained L1 SignalService proxy:", signalService_);
        console2.log("Export INBOX_PROXY, then deploy and populate its registry.");
    }

    /// @notice Deploys the switching Etna implementation for the scheduling proposal or a
    /// postponement before the start write.
    /// @return inboxImpl_ New implementation configured over the existing SignalService.
    function deployInbox() external override returns (address inboxImpl_) {
        IEtnaInbox.Config memory config = _inboxConfig();
        _checkVerifierPolicy(config.proofVerifier);
        vm.startBroadcast(_privateKey());
        inboxImpl_ = address(new EtnaInbox(config));
        vm.stopBroadcast();
        console2.log("ETNA_INBOX_IMPLEMENTATION:", inboxImpl_);
    }

    /// @notice Returns the call to INBOX_PROXY that installs or replaces the Etna Inbox
    /// implementation.
    /// @dev The bootstrap needs initialization. An initialized switching Inbox can be replaced
    /// before its start write, preserving all proxy state (SWITCH.md section 7).
    /// @param _inboxImpl The prepared Etna Inbox implementation.
    /// @return The calldata for INBOX_PROXY.
    function ownerUpgradeCall(address _inboxImpl) external view returns (bytes memory) {
        _liveUnzenConfig();
        if (_isReplacement(_etnaProxy())) {
            return abi.encodeCall(UUPSUpgradeable.upgradeTo, (_inboxImpl));
        }
        return ownerInitCall(_inboxImpl);
    }

    /// @notice Deploys the Unzen cutoff implementation with the live Inbox's config, except that
    /// `prove` saves its checkpoints through the Etna Inbox proxy (START-10-5d).
    /// @return inboxImpl_ Upgrade-compatible implementation; the existing proxy is untouched.
    function deployUnzenInboxImplementation() external returns (address inboxImpl_) {
        IInbox.Config memory config = _cutoffConfig();
        EtnaSwitchGuard.Schedule memory schedule = _schedule();
        vm.startBroadcast(_privateKey());
        inboxImpl_ = address(
            new InboxWithEtnaCutoffs(
                config, schedule.etnaForkTime, schedule.proposeMargin, schedule.fiMargin
            )
        );
        vm.stopBroadcast();
        _checkCutoffImplementation(inboxImpl_, config, schedule);
        console2.log("UNZEN_INBOX_IMPLEMENTATION:", inboxImpl_);
        console2.log("ETNA_FORK_TIME:", schedule.etnaForkTime);
        console2.log("PROPOSE_CUTOFF:", InboxWithEtnaCutoffs(inboxImpl_).proposeCutoff());
        console2.log("FI_CUTOFF:", InboxWithEtnaCutoffs(inboxImpl_).FI_CUTOFF());
    }

    /// @notice Deploys the shared SignalService implementation in its L1 configuration, without
    /// upgrading the proxy: the Etna Inbox proxy as its only syncer and `usesBeaconRoots` false
    /// (START-10-5). It keeps `VERSION`, so the Unzen Inbox's checkpoints stay readable.
    /// @return signalImpl_ New implementation, preserving the existing extra pause authority.
    function deploySignalServiceImplementation() external returns (address signalImpl_) {
        _liveUnzenConfig();
        address proxy = _etnaProxy();
        address remote = vm.envAddress("REMOTE_SIGNAL_SERVICE");
        require(
            remote == l2SignalServiceAddress(_envUint64("L2_CHAIN_ID")),
            RemoteSignalServiceMismatch()
        );
        address pauser = _signalPauser(vm.envAddress("SIGNAL_SERVICE"));
        vm.startBroadcast(_privateKey());
        signalImpl_ = address(new SignalService(proxy, remote, pauser, false));
        vm.stopBroadcast();
        console2.log("SIGNAL_SERVICE_IMPLEMENTATION (VERSION=1):", signalImpl_);
        console2.log("Existing pauser:", pauser);
    }

    /// @notice Deploys the stateless `EtnaSwitchGuard` whose reverting checks the scheduling and
    /// postponement batches call (SWITCH.md sections 3 and 7).
    /// @return guard_ The guard; export it as SWITCH_GUARD.
    function deploySwitchGuard() external returns (address guard_) {
        vm.startBroadcast(_privateKey());
        guard_ = address(new EtnaSwitchGuard());
        vm.stopBroadcast();
        console2.log("SWITCH_GUARD:", guard_);
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Production deployments require an explicit owner, independently of the broadcast key.
    /// @return owner_ The configured non-zero DAO owner.
    function _owner(uint256) internal view override returns (address owner_) {
        require(
            vm.envExists("CONTRACT_OWNER") && bytes(vm.envString("CONTRACT_OWNER")).length != 0,
            ExplicitOwnerRequired()
        );
        owner_ = vm.envAddress("CONTRACT_OWNER");
        require(owner_ != address(0), ExplicitOwnerRequired());
    }

    /// @dev Validates the target L1 and bootstrap before preparing a registry that fixes its Inbox.
    /// @return config_ The unchanged new-network registry parameters for this switching proxy.
    function _registryConfig()
        internal
        view
        override
        returns (IEtnaStakingRegistry.Config memory config_)
    {
        _liveUnzenConfig();
        _etnaProxy();
        return super._registryConfig();
    }

    /// @dev Checks the switching identities and that every Etna verifier instance is isolated.
    /// @return config_ Etna configuration with all three switching immutables populated.
    function _inboxConfig() internal view override returns (IEtnaInbox.Config memory config_) {
        IInbox.Config memory cutoffConfig = _cutoffConfig();
        EtnaSwitchGuard.Schedule memory schedule = _schedule();
        config_ = super._inboxConfig();
        address proxy = cutoffConfig.signalService;
        _requireOwner(config_.stakingRegistry);
        config_.unzenInbox = vm.envAddress("UNZEN_INBOX");
        config_.etnaForkTime = schedule.etnaForkTime;
        _checkCutoffImplementation(
            vm.envAddress("UNZEN_INBOX_IMPLEMENTATION"), cutoffConfig, schedule
        );
        require(
            IEtnaStakingRegistry(config_.stakingRegistry).inbox() == proxy
                && IEtnaStakingRegistry(config_.stakingRegistry).l2ChainId() == config_.l2ChainId,
            SwitchIdentityMismatch()
        );
        _checkVerifiers(config_.proofVerifier, cutoffConfig.proofVerifier, config_.l2ChainId);
    }

    /// @dev Opens the existing Unzen proxy and SignalService, never a fresh replacement store. The
    /// live `signalService` is SIGNAL_SERVICE before the scheduling proposal executes and
    /// INBOX_PROXY after it (SWITCH.md section 3); any other value is refused. After it,
    /// SIGNAL_SERVICE must be the store the installed Etna Inbox saves into, the one holding
    /// Unzen's checkpoints.
    /// @return config_ The live Unzen Inbox configuration, unchanged.
    function _liveUnzenConfig() internal view returns (IInbox.Config memory config_) {
        _owner(0);
        require(vm.envUint("L1_CHAIN_ID") == block.chainid, L1ChainIdMismatch());
        address unzen = vm.envAddress("UNZEN_INBOX");
        address signal = vm.envAddress("SIGNAL_SERVICE");
        _requireProxy(unzen);
        _requireProxy(signal);
        _requireOwner(unzen);
        _requireOwner(signal);
        config_ = IInbox(unzen).getConfig();
        require(SignalService(signal).VERSION() == 1, SwitchIdentityMismatch());
        if (config_.signalService != signal) {
            require(
                vm.envExists("INBOX_PROXY") && config_.signalService == _etnaProxy()
                    && IEtnaInbox(config_.signalService).signalService() == signal,
                SwitchIdentityMismatch()
            );
        }
        require(IInbox(unzen).getCoreState().nextProposalId != 0, SwitchIdentityMismatch());
    }

    /// @dev Checks INBOX_PROXY before anything that names it is prepared: a DAO-owned proxy with
    /// no pending transfer, distinct from the Unzen Inbox and the retained SignalService.
    /// @return proxy_ The Etna Inbox proxy.
    function _etnaProxy() internal view returns (address proxy_) {
        proxy_ = vm.envAddress("INBOX_PROXY");
        _requireProxy(proxy_);
        _requireOwner(proxy_);
        require(
            proxy_ != vm.envAddress("UNZEN_INBOX") && proxy_ != vm.envAddress("SIGNAL_SERVICE"),
            SwitchIdentityMismatch()
        );
    }

    /// @dev Reports whether the switch Inbox has been initialized and rejects a replacement
    /// after the start write.
    /// @param _proxy The switching Etna Inbox proxy.
    /// @return replacement_ Whether the proxy already holds initialized Etna state.
    function _isReplacement(address _proxy) internal view returns (bool replacement_) {
        replacement_ = IEtnaInbox(_proxy).isInitialized();
        if (replacement_) {
            (, bytes32 startHash) = IEtnaInbox(_proxy).etnaStart();
            require(startHash == 0, SwitchAlreadyStarted());
        }
    }

    /// @dev Reads the schedule from ETNA_FORK_TIME, PROPOSE_MARGIN and FI_MARGIN. Once the Etna
    /// Inbox is initialized the schedule is a postponement, so the fork time must be later than
    /// the installed one.
    /// @return schedule_ The schedule to deploy or install.
    function _schedule() internal view returns (EtnaSwitchGuard.Schedule memory schedule_) {
        schedule_.etnaForkTime = SafeCast.toUint48(vm.envUint("ETNA_FORK_TIME"));
        schedule_.proposeMargin = SafeCast.toUint48(vm.envUint("PROPOSE_MARGIN"));
        schedule_.fiMargin = SafeCast.toUint48(vm.envUint("FI_MARGIN"));
        require(schedule_.etnaForkTime != 0, SwitchIdentityMismatch());
        address proxy = _etnaProxy();
        if (_isReplacement(proxy)) {
            require(schedule_.etnaForkTime > IEtnaInbox(proxy).etnaForkTime(), ForkTimeNotLater());
        }
    }

    /// @dev Requires a deployed cutoff implementation with `_config` and `_expected`: its fork
    /// time is the schedule's, and its live `proposeCutoff()` and `FI_CUTOFF()` sit the schedule's
    /// margins before it.
    /// @param _impl The `InboxWithEtnaCutoffs` implementation.
    /// @param _config The configuration it must report.
    /// @param _expected The schedule it must enforce.
    function _checkCutoffImplementation(
        address _impl,
        IInbox.Config memory _config,
        EtnaSwitchGuard.Schedule memory _expected
    )
        internal
        view
    {
        InboxWithEtnaCutoffs cutoff = InboxWithEtnaCutoffs(_impl);
        require(
            _impl.code.length != 0
                && keccak256(abi.encode(cutoff.getConfig())) == keccak256(abi.encode(_config)),
            SwitchIdentityMismatch()
        );
        require(
            cutoff.ETNA_FORK_TIME() == _expected.etnaForkTime
                && uint256(cutoff.proposeCutoff()) + _expected.proposeMargin
                    == _expected.etnaForkTime
                && uint256(cutoff.FI_CUTOFF()) + _expected.fiMargin == _expected.etnaForkTime,
            ScheduleMismatch()
        );
    }

    /// @dev The cutoff implementation's configuration: the live one with `signalService` set to
    /// the Etna Inbox proxy, through which `prove` then saves its checkpoints (START-10-5d).
    /// @return config_ The configuration to construct `InboxWithEtnaCutoffs` with.
    function _cutoffConfig() internal view returns (IInbox.Config memory config_) {
        config_ = _liveUnzenConfig();
        config_.signalService = _etnaProxy();
    }

    /// @dev Compares the actual policy bytecode to this build's ZkRequiredVerifier with identical
    /// immutable addresses. The reference contract is created in the script's local EVM before
    /// startBroadcast, so it is never included in the deployment transaction list.
    /// @param _verifier The separately deployed Etna composite verifier to authenticate.
    function _checkVerifierPolicy(address _verifier) internal {
        ComposeVerifier candidate = ComposeVerifier(_verifier);
        ZkRequiredVerifier expected = new ZkRequiredVerifier(
            candidate.sgxGethVerifier(),
            candidate.sgxRethVerifier(),
            candidate.risc0RethVerifier(),
            candidate.sp1RethVerifier()
        );
        require(_verifier.codehash == address(expected).codehash, SwitchIdentityMismatch());
    }

    /// @dev Reads a live extra pause authority; pre-pauser implementations have no getter.
    /// @param _signal Existing L1 SignalService proxy.
    /// @return pauser_ Existing authority, or zero when the old implementation has none.
    function _signalPauser(address _signal) internal view returns (address pauser_) {
        (bool ok, bytes memory data) = _signal.staticcall(abi.encodeWithSignature("pauser()"));
        if (data.length == 0) return address(0);
        require(ok && data.length == 32, SwitchIdentityMismatch());
        return abi.decode(data, (address));
    }

    /// @dev Requires installed ownership, with no in-flight transfer, on every mutable control
    /// surface the switch will rely on. Both proxy and verifier owners expose these selectors.
    /// @param _controlled The Inbox, registry, SignalService or image-trusting verifier.
    function _requireOwner(address _controlled) internal view {
        require(
            EssentialContract(_controlled).owner() == _owner(0)
                && EssentialContract(_controlled).pendingOwner() == address(0),
            SwitchIdentityMismatch()
        );
    }

    /// @dev Leaves the switching start unwritten; initialization cannot import block-zero values.
    /// @return hash_ Zero until `setOrigin` writes S.
    /// @return root_ Zero until `setOrigin` writes S.
    function _genesisBlock() internal pure override returns (bytes32 hash_, bytes32 root_) { }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Requires a separate ZkRequiredVerifier topology and no shared image-trusting instances.
    /// @param _etna Etna's composite verifier.
    /// @param _unzen Unzen's currently configured composite verifier.
    /// @param _chainId Expected L2 identity of every Etna sub-verifier.
    function _checkVerifiers(address _etna, address _unzen, uint64 _chainId) private view {
        require(
            _etna != _unzen && _etna.code.length != 0 && _unzen.code.length != 0,
            SwitchIdentityMismatch()
        );
        ComposeVerifier etna = ComposeVerifier(_etna);
        ComposeVerifier unzen = ComposeVerifier(_unzen);
        require(
            etna.opVerifier() == address(0) && etna.tdxGethVerifier() == address(0),
            SwitchIdentityMismatch()
        );
        address[4] memory next = [
            etna.sgxGethVerifier(),
            etna.sgxRethVerifier(),
            etna.risc0RethVerifier(),
            etna.sp1RethVerifier()
        ];
        require(
            next[1] != address(0) && next[2] != address(0) && next[3] != address(0),
            SwitchIdentityMismatch()
        );
        address[6] memory previous;
        for (uint8 i; i < previous.length; ++i) {
            previous[i] = unzen.getVerifierAddress(ComposeVerifier.VerifierType(i + 1));
            if (previous[i] != address(0)) {
                require(
                    previous[i].code.length != 0
                        && IEtnaVerifierIdentity(previous[i]).taikoChainId() == _chainId,
                    SwitchIdentityMismatch()
                );
            }
        }
        for (uint256 i; i < next.length; ++i) {
            if (next[i] == address(0)) continue;
            _requireOwner(next[i]);
            require(
                next[i].code.length != 0
                    && IEtnaVerifierIdentity(next[i]).taikoChainId() == _chainId,
                SwitchIdentityMismatch()
            );
            for (uint256 j; j < i; ++j) {
                require(next[i] != next[j], SwitchIdentityMismatch());
            }
            for (uint256 j; j < previous.length; ++j) {
                require(next[i] != previous[j], SwitchIdentityMismatch());
            }
        }
    }

    /// @dev Rejects accidental use of an implementation address in place of an existing proxy.
    /// @param _proxy EssentialContract proxy with a deployed implementation.
    function _requireProxy(address _proxy) private view {
        require(
            _proxy.code.length != 0 && EssentialContract(_proxy).impl().code.length != 0,
            SwitchIdentityMismatch()
        );
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error SwitchIdentityMismatch();
    error ExplicitOwnerRequired();
    error SwitchAlreadyStarted();
    error ScheduleMismatch();
    error ForkTimeNotLater();
}
