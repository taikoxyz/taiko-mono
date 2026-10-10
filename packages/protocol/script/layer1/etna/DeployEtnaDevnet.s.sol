// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Script, console2 } from "forge-std/src/Script.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { DevnetInbox } from "src/layer1/devnet/DevnetInbox.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";

/// @title DeployEtnaDevnet
/// @notice Deploys the Etna L1 contracts of a devnet next to its live Shasta `DevnetInbox` proxy
/// and logs the two owner calls that migrate that proxy to Etna.
/// @dev Deploys, from `PRIVATE_KEY`:
/// - the `EtnaStakingRegistry` implementation and its `ERC1967Proxy`, initialized to
///   `CONTRACT_OWNER`;
/// - a `DevnetInbox` implementation, which carries `freeze()`, built from the live proxy's five
///   address immutables; the script aborts before broadcasting unless its `getConfig()` equals
///   the live one, so the freeze upgrade changes no configuration;
/// - the `EtnaInbox` implementation. It takes the signal service, the bond token and the legacy
///   bond parameters from the live proxy, so the legacy bond exit keeps its token and rules.
///
/// It upgrades nothing and calls nothing on the Inbox proxy. The Inbox owner then sends, to
/// `INBOX_PROXY`:
/// 1. `upgradeToAndCall(devnetInboxImpl, freeze())`, logged by `run`;
/// 2. once every Shasta proposal is proven, `upgradeToAndCall(etnaInboxImpl, activateEtna(..))`.
///    `run` logs it when `COMMITTEE_RECORD_HASH` is set. The genesis height is only final after
///    the drain and the record hash is computed from the registry at the genesis cutoff, so the
///    usual path is to run `logActivation(address)` with `--sig` at that point.
///
/// The registry proxy is created directly rather than through `DeployCapability.deployProxy`,
/// which would rewrite `deployments/deploy_l1.json` with this run's entries only.
///
/// Environment:
/// - `PRIVATE_KEY`; `INBOX_PROXY`, the live Shasta Inbox proxy.
/// - `ETNA_PROOF_VERIFIER`: the `IProofVerifier` of `land` proofs. No Etna guest exists yet, so
///   a devnet passes a stand-in verifier.
/// - `L2_CHAIN_ID`; `MAX_BATCH_BLOCKS`, the most L2 blocks one `land` call may cover.
/// - `CONTRACT_OWNER`: the registry owner; the deployer if unset or zero.
/// - `TAIKO_TOKEN`: the staked token; the live Inbox's bond token if unset or zero.
/// - `REGISTRY_MIN_STAKE` (TAIKO base units), `REGISTRY_ACTIVATION_DELAY`,
///   `REGISTRY_EXIT_DELAY`, `REGISTRY_WITHDRAWAL_DELAY`, `REGISTRY_HEARTBEAT_WINDOW` (L1 blocks):
///   they must match the Etna node's chain constants.
/// - Activation (for the second call): `GENESIS_HEIGHT`, `EPOCH_LEN_L2`, `EPOCH_LEN_L1`,
///   `GENESIS_CUTOFF`, `COMMITTEE_RECORD_HASH`.
/// @custom:security-contact security@taiko.xyz
contract DeployEtnaDevnet is Script {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev The deployment parameters read from the environment.
    struct Params {
        address inbox;
        address owner;
        address taikoToken;
        address etnaProofVerifier;
        uint64 l2ChainId;
        uint64 maxBatchBlocks;
        uint256 minStake;
        uint64 activationDelay;
        uint64 exitDelay;
        uint64 withdrawalDelay;
        uint64 heartbeatWindow;
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Deploys the registry proxy, the `DevnetInbox` and the `EtnaInbox` implementations,
    /// and logs the owner calls.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, InvalidPrivateKey());

        Params memory params = _loadParams();
        IInbox.Config memory live = IInbox(params.inbox).getConfig();
        if (params.taikoToken == address(0)) params.taikoToken = live.bondToken;

        vm.startBroadcast(privateKey);
        address registry = _deployRegistry(params);
        address devnetInboxImpl = address(
            new DevnetInbox(
                live.proofVerifier,
                live.proposerChecker,
                live.proverWhitelist,
                live.signalService,
                live.bondToken
            )
        );
        IEtnaInbox.Config memory etnaConfig = IEtnaInbox.Config({
            proofVerifier: params.etnaProofVerifier,
            signalService: live.signalService,
            stakingRegistry: registry,
            bondToken: live.bondToken,
            l2ChainId: params.l2ChainId,
            maxBatchBlocks: params.maxBatchBlocks,
            minBond: live.minBond,
            withdrawalDelay: live.withdrawalDelay
        });
        address etnaInboxImpl = address(new EtnaInbox(etnaConfig));
        vm.stopBroadcast();

        require(
            keccak256(abi.encode(IInbox(devnetInboxImpl).getConfig()))
                == keccak256(abi.encode(live)),
            InboxConfigMismatch()
        );

        console2.log("EtnaStakingRegistry proxy:", registry);
        console2.log("  owner              :", EtnaStakingRegistry(registry).owner());
        console2.log("  taikoToken         :", params.taikoToken);
        console2.log("DevnetInbox impl (freeze):", devnetInboxImpl);
        _logEtnaInbox(etnaInboxImpl, etnaConfig);

        console2.log("Owner call 1, to INBOX_PROXY", params.inbox);
        console2.log("  upgradeToAndCall(DevnetInbox impl, freeze()):");
        console2.logBytes(
            abi.encodeCall(
                UUPSUpgradeable.upgradeToAndCall,
                (devnetInboxImpl, abi.encodeCall(Inbox.freeze, ()))
            )
        );

        if (vm.envOr("COMMITTEE_RECORD_HASH", bytes32(0)) != 0) {
            logActivation(etnaInboxImpl);
        } else {
            console2.log("Owner call 2: once drained, set the activation variables and run");
            console2.log("  logActivation(address) with --sig and the EtnaInbox impl above");
        }
    }

    /// @notice Logs the second owner call, `upgradeToAndCall(_etnaInboxImpl, activateEtna(..))`,
    /// with the activation parameters from the environment.
    /// @param _etnaInboxImpl The `EtnaInbox` implementation deployed by `run`.
    function logActivation(address _etnaInboxImpl) public view {
        IEtnaInbox.ActivationParams memory activation = IEtnaInbox.ActivationParams({
            genesisHeight: _envUint64("GENESIS_HEIGHT"),
            epochLenL2: _envUint64("EPOCH_LEN_L2"),
            epochLenL1: _envUint64("EPOCH_LEN_L1"),
            genesisCutoff: _envUint64("GENESIS_CUTOFF"),
            committeeRecordHash: vm.envBytes32("COMMITTEE_RECORD_HASH")
        });

        console2.log("Owner call 2, to INBOX_PROXY", vm.envAddress("INBOX_PROXY"));
        console2.log("  genesisHeight      :", activation.genesisHeight);
        console2.log("  epochLenL2         :", activation.epochLenL2);
        console2.log("  epochLenL1         :", activation.epochLenL1);
        console2.log("  genesisCutoff      :", activation.genesisCutoff);
        console2.log("  committeeRecordHash:");
        console2.logBytes32(activation.committeeRecordHash);
        console2.log("  upgradeToAndCall(EtnaInbox impl, activateEtna(params)):");
        console2.logBytes(
            abi.encodeCall(
                UUPSUpgradeable.upgradeToAndCall,
                (_etnaInboxImpl, abi.encodeCall(IEtnaInbox.activateEtna, (activation)))
            )
        );
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Reads the deployment parameters from the environment.
    /// @return params_ The parameters; `taikoToken` is zero when unset.
    function _loadParams() private view returns (Params memory params_) {
        params_.inbox = vm.envAddress("INBOX_PROXY");
        params_.owner = vm.envOr("CONTRACT_OWNER", address(0));
        params_.taikoToken = vm.envOr("TAIKO_TOKEN", address(0));
        params_.etnaProofVerifier = vm.envAddress("ETNA_PROOF_VERIFIER");
        params_.l2ChainId = _envUint64("L2_CHAIN_ID");
        params_.maxBatchBlocks = _envUint64("MAX_BATCH_BLOCKS");
        params_.minStake = vm.envUint("REGISTRY_MIN_STAKE");
        params_.activationDelay = _envUint64("REGISTRY_ACTIVATION_DELAY");
        params_.exitDelay = _envUint64("REGISTRY_EXIT_DELAY");
        params_.withdrawalDelay = _envUint64("REGISTRY_WITHDRAWAL_DELAY");
        params_.heartbeatWindow = _envUint64("REGISTRY_HEARTBEAT_WINDOW");
    }

    /// @dev Deploys the registry implementation and its proxy. A zero owner makes the deployer
    /// the owner.
    /// @param _params The deployment parameters.
    /// @return registry_ The registry proxy.
    function _deployRegistry(Params memory _params) private returns (address registry_) {
        address impl = address(
            new EtnaStakingRegistry(
                _params.taikoToken,
                _params.minStake,
                _params.activationDelay,
                _params.exitDelay,
                _params.withdrawalDelay,
                _params.heartbeatWindow
            )
        );
        registry_ = address(
            new ERC1967Proxy(impl, abi.encodeCall(EtnaStakingRegistry.init, (_params.owner)))
        );
    }

    /// @dev Logs the `EtnaInbox` implementation and the configuration it was built with, as the
    /// contract exposes no configuration getter.
    /// @param _impl The implementation.
    /// @param _config Its constructor configuration.
    function _logEtnaInbox(address _impl, IEtnaInbox.Config memory _config) private pure {
        console2.log("EtnaInbox impl:", _impl);
        console2.log("  proofVerifier      :", _config.proofVerifier);
        console2.log("  signalService      :", _config.signalService);
        console2.log("  stakingRegistry    :", _config.stakingRegistry);
        console2.log("  bondToken          :", _config.bondToken);
        console2.log("  l2ChainId          :", _config.l2ChainId);
        console2.log("  maxBatchBlocks     :", _config.maxBatchBlocks);
        console2.log("  minBond            :", _config.minBond);
        console2.log("  withdrawalDelay    :", _config.withdrawalDelay);
    }

    /// @dev Reads a `uint64` from the environment, reverting if it does not fit.
    /// @param _name The variable name.
    /// @return The value.
    function _envUint64(string memory _name) private view returns (uint64) {
        return SafeCast.toUint64(vm.envUint(_name));
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidPrivateKey();
    error InboxConfigMismatch();
}
