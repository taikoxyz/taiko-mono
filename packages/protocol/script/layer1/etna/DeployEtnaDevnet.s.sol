// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Script, console2 } from "forge-std/src/Script.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title DeployEtnaDevnet
/// @notice Deploys a new Etna chain starting from L2 block 0.
/// @dev First run `run()` to deploy the registry. Register validators, wait for their activation
/// and L1 finality, then compute committee 0 at a past genesis cutoff. Call `deployInbox()` to
/// deploy fresh SignalService and EtnaInbox proxies; the Inbox constructor call initializes the
/// genesis record and saves the block-0 checkpoint atomically. No existing Inbox is required.
///
/// Environment shared by both calls: PRIVATE_KEY; optional CONTRACT_OWNER (the deployer if zero).
/// `run()`: TAIKO_TOKEN, REGISTRY_MIN_STAKE (base units), REGISTRY_ACTIVATION_DELAY,
/// REGISTRY_EXIT_DELAY, REGISTRY_WITHDRAWAL_DELAY, REGISTRY_HEARTBEAT_WINDOW (L1 blocks),
/// REGISTRY_CHURN_WINDOW (L1 blocks; 0 disables the churn limit), REGISTRY_CHURN_BPS and
/// REGISTRY_MIN_CHURN_PER_WINDOW (base units).
/// `deployInbox()`: STAKING_REGISTRY, ETNA_PROOF_VERIFIER, REMOTE_SIGNAL_SERVICE (on L2),
/// L2_CHAIN_ID, MAX_BATCH_BLOCKS, FORCED_INCLUSION_FEE_GWEI (non-zero),
/// FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD (non-zero), GENESIS_BLOCK_HASH, GENESIS_STATE_ROOT,
/// EPOCH_LEN_L2, EPOCH_LEN_L1, GENESIS_CUTOFF, COMMITTEE_RECORD_HASH, COMMITTEE_CONFIG_HASH,
/// FORCED_INCLUSION_DELAY (seconds, non-zero) and MAX_ANCHOR_AGE (seconds, at least 1152, above
/// the expected L1 finality lag). There is no expiry-derived upper bound. The genesis values must
/// match the L2 genesis file and the committee derived by
/// taiko-client-rs. The node requires EPOCH_LEN_L2 >= D_MAX - MARGIN_V + 3; heartbeat and stake
/// parameters must match its constants.
///
/// No Etna guest exists yet. An accept-all ETNA_PROOF_VERIFIER is DEVNET ONLY: permissionless
/// landing would otherwise allow anyone to forge checkpoints and to consume pending forced
/// inclusions without including them, collecting their fees.
/// @custom:security-contact security@taiko.xyz
contract DeployEtnaDevnet is Script {
    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Deploys an initialized staking registry proxy for a new Etna chain.
    /// @return registry_ The staking registry proxy.
    function run() external returns (address registry_) {
        uint256 privateKey = _privateKey();
        address owner = _owner(privateKey);

        vm.startBroadcast(privateKey);
        address impl = _newRegistryImpl();
        registry_ =
            address(new ERC1967Proxy(impl, abi.encodeCall(EtnaStakingRegistry.init, (owner))));
        vm.stopBroadcast();

        console2.log("EtnaStakingRegistry proxy:", registry_);
        console2.log("  owner:", owner);
        console2.log("Register validators and compute committee 0 before deploying the Inbox.");
    }

    /// @notice Deploys fresh SignalService and EtnaInbox proxies initialized from L2 genesis.
    /// @dev Four consecutive CREATEs are broadcast from one deployer. Predicts the final proxy
    /// address so the SignalService authorizes it before the Inbox initializes its checkpoint.
    /// COMMITTEE_CONFIG_HASH must be the canonical ETNA_PARENT_ANCHOR_V2 opening for this chain
    /// and registry, matching node parameters (including d_max and margin_v). Fixture inputs may use a dummy verifier only on
    /// ephemeral devnets; ETNA_PROOF_VERIFIER must explicitly select that deployed verifier.
    /// @return inbox_ The new EtnaInbox proxy.
    /// @return signalService_ The new L1 SignalService proxy.
    function deployInbox() external returns (address inbox_, address signalService_) {
        uint256 privateKey = _privateKey();
        address owner = _owner(privateKey);
        // The SignalService proxy is set once deployed; one struct keeps the stack shallow.
        IEtnaInbox.Config memory config = IEtnaInbox.Config({
            proofVerifier: vm.envAddress("ETNA_PROOF_VERIFIER"),
            signalService: address(0),
            stakingRegistry: vm.envAddress("STAKING_REGISTRY"),
            l2ChainId: _envUint64("L2_CHAIN_ID"),
            maxBatchBlocks: _envUint64("MAX_BATCH_BLOCKS"),
            forcedInclusionFeeInGwei: _envUint64("FORCED_INCLUSION_FEE_GWEI"),
            forcedInclusionFeeDoubleThreshold: _envUint64("FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD")
        });
        require(config.proofVerifier.code.length != 0, ProofVerifierHasNoCode());
        address remoteSignalService = vm.envAddress("REMOTE_SIGNAL_SERVICE");
        IEtnaInbox.GenesisParams memory genesis = IEtnaInbox.GenesisParams({
            genesisBlockHash: vm.envBytes32("GENESIS_BLOCK_HASH"),
            genesisStateRoot: vm.envBytes32("GENESIS_STATE_ROOT"),
            epochLenL2: _envUint64("EPOCH_LEN_L2"),
            epochLenL1: _envUint64("EPOCH_LEN_L1"),
            genesisCutoff: _envUint64("GENESIS_CUTOFF"),
            committeeRecordHash: vm.envBytes32("COMMITTEE_RECORD_HASH"),
            committeeConfigHash: vm.envBytes32("COMMITTEE_CONFIG_HASH"),
            forcedInclusionDelay: _envUint64("FORCED_INCLUSION_DELAY"),
            maxAnchorAge: _envUint64("MAX_ANCHOR_AGE")
        });
        address deployer = vm.addr(privateKey);
        address predictedInbox = vm.computeCreateAddress(deployer, vm.getNonce(deployer) + 3);

        vm.startBroadcast(privateKey);
        address signalImpl = address(new SignalService(predictedInbox, remoteSignalService, owner));
        signalService_ =
            address(new ERC1967Proxy(signalImpl, abi.encodeCall(SignalService.init, (owner))));
        config.signalService = signalService_;
        address inboxImpl = address(new EtnaInbox(config));
        inbox_ = address(
            new ERC1967Proxy(inboxImpl, abi.encodeCall(EtnaInbox.init, (owner, genesis)))
        );
        vm.stopBroadcast();
        require(inbox_ == predictedInbox, InboxAddressMismatch());

        console2.log("EtnaInbox proxy:", inbox_);
        console2.log("SignalService proxy:", signalService_);
        console2.log("Staking registry:", config.stakingRegistry);
        console2.log("Owner:", owner);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Reads a non-zero deployment key.
    /// @return The key passed to the broadcast cheatcode.
    function _privateKey() private view returns (uint256) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        require(key != 0, InvalidPrivateKey());
        return key;
    }

    /// @dev Reads the proxy owner, falling back to the deployer.
    /// @param _privateKey The deployment key.
    /// @return The owner of newly deployed proxies.
    function _owner(uint256 _privateKey) private view returns (address) {
        address owner = vm.envOr("CONTRACT_OWNER", address(0));
        return owner == address(0) ? vm.addr(_privateKey) : owner;
    }

    /// @dev Deploys the registry implementation from the REGISTRY_* environment.
    /// @return The registry implementation.
    function _newRegistryImpl() private returns (address) {
        return address(
            new EtnaStakingRegistry(
                vm.envAddress("TAIKO_TOKEN"),
                vm.envUint("REGISTRY_MIN_STAKE"),
                _envUint64("REGISTRY_ACTIVATION_DELAY"),
                _envUint64("REGISTRY_EXIT_DELAY"),
                _envUint64("REGISTRY_WITHDRAWAL_DELAY"),
                _envUint64("REGISTRY_HEARTBEAT_WINDOW"),
                _envUint64("REGISTRY_CHURN_WINDOW"),
                SafeCast.toUint16(vm.envUint("REGISTRY_CHURN_BPS")),
                vm.envUint("REGISTRY_MIN_CHURN_PER_WINDOW")
            )
        );
    }

    /// @dev Reads an environment integer and rejects values outside uint64.
    /// @param _name The variable name.
    /// @return The uint64 value.
    function _envUint64(string memory _name) private view returns (uint64) {
        return SafeCast.toUint64(vm.envUint(_name));
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InboxAddressMismatch();
    error InvalidPrivateKey();
    error ProofVerifierHasNoCode();
}
