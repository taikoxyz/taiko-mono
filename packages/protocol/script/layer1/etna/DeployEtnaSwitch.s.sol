// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployEtnaDevnet } from "./DeployEtnaDevnet.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { console2 } from "forge-std/src/Script.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxWithEtnaCutoffs } from "src/layer1/core/impl/InboxWithEtnaCutoffs.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { ComposeVerifier } from "src/layer1/verifiers/compose/ComposeVerifier.sol";
import { ZkRequiredVerifier } from "src/layer1/verifiers/compose/ZkRequiredVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { SignalServiceL1 } from "src/shared/signal/SignalServiceL1.sol";

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
/// UNZEN_INBOX, SIGNAL_SERVICE (the existing L1 proxy), ORIGIN_WRITER, ETNA_FORK_TIME,
/// PROPOSE_MARGIN and FI_MARGIN. Export the deployed cutoff implementation as
/// UNZEN_INBOX_IMPLEMENTATION before deployInbox. REMOTE_SIGNAL_SERVICE is the existing L2 proxy. GENESIS_BLOCK_HASH
/// and GENESIS_STATE_ROOT are not read: the start remains unwritten until setOrigin. Deploy the
/// bootstrap, then its registry, dedicated verifiers, and the three implementations. All four
/// deployment entry points only create contracts; installation/DAO batches and setOrigin are
/// separate operations. Inherited deployRegistry likewise creates only a new registry proxy.
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

    /// @notice Deploys the switching Etna implementation without installing or initializing it.
    /// @return inboxImpl_ New implementation configured over the existing SignalService.
    function deployInbox() external override returns (address inboxImpl_) {
        IEtnaInbox.Config memory config = _inboxConfig();
        _checkVerifierPolicy(config.proofVerifier);
        vm.startBroadcast(_privateKey());
        inboxImpl_ = address(new EtnaInbox(config));
        vm.stopBroadcast();
        console2.log("Switching Etna Inbox implementation:", inboxImpl_);
        console2.log(
            "No proxy upgraded; initialize atomically on installation with zero start values."
        );
    }

    /// @notice Deploys the Unzen cutoff implementation with the live Inbox's unchanged config.
    /// @return inboxImpl_ Upgrade-compatible implementation; the existing proxy is untouched.
    function deployUnzenInboxImplementation() external returns (address inboxImpl_) {
        IInbox.Config memory config = _liveUnzenConfig();
        uint48 forkTime = _forkTime();
        uint48 proposeMargin = SafeCast.toUint48(vm.envUint("PROPOSE_MARGIN"));
        uint48 fiMargin = SafeCast.toUint48(vm.envUint("FI_MARGIN"));
        vm.startBroadcast(_privateKey());
        inboxImpl_ = address(new InboxWithEtnaCutoffs(config, forkTime, proposeMargin, fiMargin));
        vm.stopBroadcast();
        console2.log("UNZEN_INBOX_IMPLEMENTATION:", inboxImpl_);
        console2.log("ETNA_FORK_TIME:", forkTime);
        console2.log("PROPOSE_CUTOFF:", InboxWithEtnaCutoffs(inboxImpl_).PROPOSE_CUTOFF());
        console2.log("FI_CUTOFF:", InboxWithEtnaCutoffs(inboxImpl_).FI_CUTOFF());
    }

    /// @notice Deploys the storage-compatible L1 dual-syncer implementation without upgrading it.
    /// @return signalImpl_ New implementation, preserving the existing extra pause authority.
    function deploySignalServiceImplementation() external returns (address signalImpl_) {
        _liveUnzenConfig();
        address proxy = vm.envAddress("INBOX_PROXY");
        address remote = vm.envAddress("REMOTE_SIGNAL_SERVICE");
        require(
            remote == l2SignalServiceAddress(_envUint64("L2_CHAIN_ID")),
            RemoteSignalServiceMismatch()
        );
        address pauser = _signalPauser(vm.envAddress("SIGNAL_SERVICE"));
        address unzen = vm.envAddress("UNZEN_INBOX");
        vm.startBroadcast(_privateKey());
        signalImpl_ = address(new SignalServiceL1(unzen, proxy, remote, pauser));
        vm.stopBroadcast();
        console2.log("L1 SignalService implementation (VERSION=1):", signalImpl_);
        console2.log("Existing pauser:", pauser);
    }

    // ---------------------------------------------------------------
    // Internal & Private Functions
    // ---------------------------------------------------------------

    /// @dev Validates the target L1 and bootstrap before preparing a registry that fixes its Inbox.
    /// @return config_ The unchanged new-network registry parameters for this switching proxy.
    function _registryConfig()
        internal
        view
        override
        returns (IEtnaStakingRegistry.Config memory config_)
    {
        _liveUnzenConfig();
        _requireProxy(vm.envAddress("INBOX_PROXY"));
        return super._registryConfig();
    }

    /// @dev Opens the existing Unzen proxy and SignalService, never a fresh replacement store.
    /// @return config_ Unchanged constructor configuration to carry into the cutoff implementation.
    function _liveUnzenConfig() private view returns (IInbox.Config memory config_) {
        require(vm.envUint("L1_CHAIN_ID") == block.chainid, L1ChainIdMismatch());
        address unzen = vm.envAddress("UNZEN_INBOX");
        address signal = vm.envAddress("SIGNAL_SERVICE");
        _requireProxy(unzen);
        _requireProxy(signal);
        config_ = IInbox(unzen).getConfig();
        require(
            config_.signalService == signal && SignalService(signal).VERSION() == 1,
            SwitchIdentityMismatch()
        );
        require(IInbox(unzen).getCoreState().nextProposalId != 0, SwitchIdentityMismatch());
    }

    /// @dev Checks the switching identities and that every Etna verifier instance is isolated.
    /// @return config_ Etna configuration with all three switching immutables populated.
    function _inboxConfig() internal view override returns (IEtnaInbox.Config memory config_) {
        IInbox.Config memory unzenConfig = _liveUnzenConfig();
        config_ = super._inboxConfig();
        address proxy = vm.envAddress("INBOX_PROXY");
        _requireProxy(proxy);
        config_.originWriter = vm.envAddress("ORIGIN_WRITER");
        config_.unzenInbox = vm.envAddress("UNZEN_INBOX");
        config_.etnaForkTime = _forkTime();
        InboxWithEtnaCutoffs cutoff =
            InboxWithEtnaCutoffs(vm.envAddress("UNZEN_INBOX_IMPLEMENTATION"));
        require(
            address(cutoff).code.length != 0 && cutoff.ETNA_FORK_TIME() == config_.etnaForkTime
                && keccak256(abi.encode(cutoff.getConfig())) == keccak256(abi.encode(unzenConfig)),
            SwitchIdentityMismatch()
        );
        require(
            config_.originWriter != address(0) && proxy != config_.unzenInbox,
            SwitchIdentityMismatch()
        );
        require(
            IEtnaStakingRegistry(config_.stakingRegistry).inbox() == proxy
                && IEtnaStakingRegistry(config_.stakingRegistry).l2ChainId() == config_.l2ChainId,
            SwitchIdentityMismatch()
        );
        _checkVerifiers(config_.proofVerifier, unzenConfig.proofVerifier, config_.l2ChainId);
    }

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

    /// @dev Compares the actual policy bytecode to this build's ZkRequiredVerifier with identical
    /// immutable addresses. The reference contract is created in the script's local EVM before
    /// startBroadcast, so it is never included in the deployment transaction list.
    /// @param _verifier The separately deployed Etna composite verifier to authenticate.
    function _checkVerifierPolicy(address _verifier) private {
        ComposeVerifier candidate = ComposeVerifier(_verifier);
        ZkRequiredVerifier expected = new ZkRequiredVerifier(
            candidate.sgxGethVerifier(),
            candidate.sgxRethVerifier(),
            candidate.risc0RethVerifier(),
            candidate.sp1RethVerifier()
        );
        require(_verifier.codehash == address(expected).codehash, SwitchIdentityMismatch());
    }

    /// @dev Leaves the switching start unwritten; initialization cannot import block-zero values.
    /// @return hash_ Zero until the originWriter writes S.
    /// @return root_ Zero until the originWriter writes S.
    function _genesisBlock() internal pure override returns (bytes32 hash_, bytes32 root_) { }

    /// @dev Narrows the shared fork timestamp without truncation.
    /// @return time_ Nonzero uint48 Unix timestamp shared by all switch implementations.
    function _forkTime() private view returns (uint48 time_) {
        time_ = SafeCast.toUint48(vm.envUint("ETNA_FORK_TIME"));
        require(time_ != 0, SwitchIdentityMismatch());
    }

    /// @dev Reads a live extra pause authority; pre-pauser implementations have no getter.
    /// @param _signal Existing L1 SignalService proxy.
    /// @return pauser_ Existing authority, or zero when the old implementation has none.
    function _signalPauser(address _signal) private view returns (address pauser_) {
        (bool ok, bytes memory data) = _signal.staticcall(abi.encodeWithSignature("pauser()"));
        if (data.length == 0) return address(0);
        require(ok && data.length == 32, SwitchIdentityMismatch());
        return abi.decode(data, (address));
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
}
