// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Script, console2 } from "forge-std/src/Script.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @title DeployEtnaDevnet
/// @notice Deploys a new Etna chain starting from L2 block 0 in the owner-initialized order (spec
/// 10 steps 1 and 5), so the Inbox proxy address exists before the registry that fixes it:
/// 1. `deployInboxProxy()`: the Inbox proxy on `EtnaInboxBootstrap`, which only sets the owner.
///    Export the proxy as INBOX_PROXY.
/// 2. `deployRegistry()`: the staking registry with INBOX_PROXY fixed as its Inbox. Export it as
///    STAKING_REGISTRY.
/// 3. Off-script: validators register with a proof of possession of their consensus key and wait
///    for activation and L1 finality; pick a past GENESIS_CUTOFF at or after the registry's first
///    checkpoint, compute committee 0's record hash and build the L2 genesis.
/// 4. `deployInbox()`: the SignalService authorizing INBOX_PROXY, then the `EtnaInbox`
///    implementation. The proxy owner upgrades to it and calls `init` in one transaction: the
///    script sends that call when the deployer owns the proxy and otherwise logs it for the owner.
/// @dev Every call reads PRIVATE_KEY (the deployer) and the optional CONTRACT_OWNER, the owner of
/// the proxies it deploys (the deployer if unset, empty or zero). An optional variable that is
/// set but malformed reverts the call instead of falling back to its default.
/// `deployInboxProxy()` reads nothing else.
/// `deployRegistry()`: INBOX_PROXY; TAIKO_TOKEN; REGISTRY_MIN_STAKE in token base units, which
/// defaults to ETNA_S_MIN if unset, empty or zero (the two are independent parameters);
/// REGISTRY_ACTIVATION_DELAY, REGISTRY_EXIT_DELAY and REGISTRY_WITHDRAWAL_DELAY in L1 blocks, each
/// in [1, 2^32);
/// SLASH_BOUNTY_BPS (at most 10,000); SLASH_SINK (non-zero); L2_CHAIN_ID.
/// `deployInbox()`: INBOX_PROXY; STAKING_REGISTRY; ETNA_PROOF_VERIFIER, which must have code;
/// REMOTE_SIGNAL_SERVICE (the L2 SignalService); L1_CHAIN_ID, which must equal this chain's id;
/// L2_CHAIN_ID, which must equal the registry's; MAX_BATCH_BLOCKS (at least 6);
/// FORCED_INCLUSION_FEE_GWEI and FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD (non-zero);
/// PROTOCOL_FEE_RECIPIENT (the DAO treasury, non-zero); GENESIS_BLOCK_HASH and GENESIS_STATE_ROOT
/// (L2 block 0); EPOCH_LEN_L2 (L, with L >= 3 and L + 1 < 2^48); GENESIS_CUTOFF;
/// COMMITTEE_RECORD_HASH; ETNA_VP_UNIT (at least 867,361,738), ETNA_S_MIN (at least
/// ETNA_VP_UNIT), ETNA_N_MAX (in [1, 4096]) and ETNA_UNSETTLED_LIMIT (U, a multiple of 6 in
/// [6, 65,532]); FORCED_INCLUSION_DELAY (seconds, non-zero); MAX_ANCHOR_AGE (seconds, at least
/// 1152).
/// The script checks only ETNA_PROOF_VERIFIER's code and L1_CHAIN_ID itself; the constructors
/// and `init` check the other bounds listed above, so a logged owner call is validated when the
/// owner sends it. Nothing on chain checks the rest, which the operator must ensure:
/// MAX_ANCHOR_AGE above the L1 finality delay (spec 11), genesis values that match the L2
/// genesis, and nodes and guests using the same configuration. A verifier that accepts every
/// proof is for ephemeral devnets only.
/// @custom:security-contact security@taiko.xyz
contract DeployEtnaDevnet is Script {
    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Deploys the Inbox proxy on its bootstrap implementation (step 1).
    /// @return proxy_ The Inbox proxy, owned by CONTRACT_OWNER or the deployer.
    function deployInboxProxy() external returns (address proxy_) {
        uint256 privateKey = _privateKey();
        address owner = _owner(privateKey);

        vm.startBroadcast(privateKey);
        address bootstrap = address(new EtnaInboxBootstrap());
        proxy_ = address(
            new ERC1967Proxy(bootstrap, abi.encodeCall(EtnaInboxBootstrap.init, (owner)))
        );
        vm.stopBroadcast();

        console2.log("EtnaInbox proxy (bootstrap):", proxy_);
        console2.log("  bootstrap implementation:", bootstrap);
        console2.log("  owner:", owner);
        console2.log("Export INBOX_PROXY, then deploy the registry.");
    }

    /// @notice Deploys the staking registry with INBOX_PROXY fixed as its Inbox (step 2).
    /// @return registry_ The registry proxy, owned by CONTRACT_OWNER or the deployer.
    function deployRegistry() external returns (address registry_) {
        uint256 privateKey = _privateKey();
        address owner = _owner(privateKey);
        IEtnaStakingRegistry.Config memory config = _registryConfig();

        vm.startBroadcast(privateKey);
        address impl = address(new EtnaStakingRegistry(config));
        registry_ =
            address(new ERC1967Proxy(impl, abi.encodeCall(EtnaStakingRegistry.init, (owner))));
        vm.stopBroadcast();

        console2.log("EtnaStakingRegistry proxy:", registry_);
        console2.log("  implementation:", impl);
        console2.log("  Inbox proxy:", config.inbox);
        console2.log("  minimum stake:", config.minStake);
        console2.log("  owner:", owner);
        console2.log("Validators register and activate before the genesis cutoff is picked.");
    }

    /// @notice Deploys the SignalService authorizing INBOX_PROXY and the `EtnaInbox`
    /// implementation, then upgrades the proxy to it and initializes it if the deployer owns the
    /// proxy (step 4).
    /// @dev Otherwise logs `ownerInitCall(inboxImpl_)` for the proxy owner to send to
    /// INBOX_PROXY. Reverts before broadcasting if ETNA_PROOF_VERIFIER has no code or L1_CHAIN_ID
    /// is not this chain's id.
    /// @return inboxImpl_ The `EtnaInbox` implementation.
    /// @return signalService_ The L1 SignalService proxy.
    function deployInbox() external returns (address inboxImpl_, address signalService_) {
        uint256 privateKey = _privateKey();
        address owner = _owner(privateKey);
        address proxy = vm.envAddress("INBOX_PROXY");
        IEtnaInbox.Config memory config = _inboxConfig();
        require(config.proofVerifier.code.length != 0, ProofVerifierHasNoCode());
        require(vm.envUint("L1_CHAIN_ID") == block.chainid, L1ChainIdMismatch());
        address remoteSignalService = vm.envAddress("REMOTE_SIGNAL_SERVICE");
        bool deployerOwnsProxy = EssentialContract(proxy).owner() == vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        address signalImpl = address(new SignalService(proxy, remoteSignalService, owner));
        signalService_ =
            address(new ERC1967Proxy(signalImpl, abi.encodeCall(SignalService.init, (owner))));
        config.signalService = signalService_;
        inboxImpl_ = address(new EtnaInbox(config));
        if (deployerOwnsProxy) {
            EssentialContract(proxy).upgradeToAndCall(inboxImpl_, _initCall());
        }
        vm.stopBroadcast();

        console2.log("SignalService proxy:", signalService_);
        console2.log("  owner:", owner);
        console2.log("EtnaInbox implementation:", inboxImpl_);
        console2.log("EtnaInbox proxy:", proxy);
        if (deployerOwnsProxy) {
            console2.log("  upgraded and initialized by its owner, the deployer");
        } else {
            console2.log("  owner:", EssentialContract(proxy).owner());
            console2.log("  still on the bootstrap; its owner must send it this call:");
            console2.logBytes(ownerInitCall(inboxImpl_));
        }
    }

    /// @notice Returns the call the Inbox proxy owner sends to INBOX_PROXY: `upgradeToAndCall` to
    /// `_inboxImpl` with `init` over the genesis environment.
    /// @param _inboxImpl The `EtnaInbox` implementation.
    /// @return The calldata.
    function ownerInitCall(address _inboxImpl) public view returns (bytes memory) {
        return abi.encodeCall(EtnaInbox.upgradeToAndCall, (_inboxImpl, _initCall()));
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

    /// @dev Reads the owner of the deployed proxies, falling back to the deployer when
    /// CONTRACT_OWNER is unset, empty or zero. A malformed value reverts.
    /// @param _key The deployment key.
    /// @return The owner.
    function _owner(uint256 _key) private view returns (address) {
        address owner = _isSet("CONTRACT_OWNER") ? vm.envAddress("CONTRACT_OWNER") : address(0);
        return owner == address(0) ? vm.addr(_key) : owner;
    }

    /// @dev Reads the registry configuration; the minimum stake, an independent parameter,
    /// defaults to ETNA_S_MIN when REGISTRY_MIN_STAKE is unset, empty or zero. A malformed value
    /// reverts.
    /// @return The registry configuration.
    function _registryConfig() private view returns (IEtnaStakingRegistry.Config memory) {
        uint256 minStake = _isSet("REGISTRY_MIN_STAKE") ? vm.envUint("REGISTRY_MIN_STAKE") : 0;
        if (minStake == 0) minStake = vm.envUint("ETNA_S_MIN");
        return IEtnaStakingRegistry.Config({
            token: vm.envAddress("TAIKO_TOKEN"),
            minStake: minStake,
            activationDelay: vm.envUint("REGISTRY_ACTIVATION_DELAY"),
            exitDelay: vm.envUint("REGISTRY_EXIT_DELAY"),
            withdrawalDelay: vm.envUint("REGISTRY_WITHDRAWAL_DELAY"),
            slashBountyBps: vm.envUint("SLASH_BOUNTY_BPS"),
            slashSink: vm.envAddress("SLASH_SINK"),
            l2ChainId: _envUint64("L2_CHAIN_ID"),
            inbox: vm.envAddress("INBOX_PROXY")
        });
    }

    /// @dev Reads the Inbox implementation's configuration; the SignalService is set once
    /// deployed.
    /// @return The Inbox configuration.
    function _inboxConfig() private view returns (IEtnaInbox.Config memory) {
        return IEtnaInbox.Config({
            proofVerifier: vm.envAddress("ETNA_PROOF_VERIFIER"),
            signalService: address(0),
            stakingRegistry: vm.envAddress("STAKING_REGISTRY"),
            l2ChainId: _envUint64("L2_CHAIN_ID"),
            maxBatchBlocks: _envUint64("MAX_BATCH_BLOCKS"),
            forcedInclusionFeeInGwei: _envUint64("FORCED_INCLUSION_FEE_GWEI"),
            forcedInclusionFeeDoubleThreshold: _envUint64("FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD"),
            protocolFeeRecipient: vm.envAddress("PROTOCOL_FEE_RECIPIENT")
        });
    }

    /// @dev Encodes `init` over the genesis environment.
    /// @return The `init` calldata.
    function _initCall() private view returns (bytes memory) {
        IEtnaInbox.InitParams memory params = IEtnaInbox.InitParams({
            genesisBlockHash: vm.envBytes32("GENESIS_BLOCK_HASH"),
            genesisStateRoot: vm.envBytes32("GENESIS_STATE_ROOT"),
            epochLenL2: vm.envUint("EPOCH_LEN_L2"),
            genesisCutoff: vm.envUint("GENESIS_CUTOFF"),
            committeeRecordHash: vm.envBytes32("COMMITTEE_RECORD_HASH"),
            committeeConfig: IEtnaInbox.CommitteeConfig({
                vpUnit: vm.envUint("ETNA_VP_UNIT"),
                sMin: vm.envUint("ETNA_S_MIN"),
                nMax: vm.envUint("ETNA_N_MAX"),
                unsettledLimit: vm.envUint("ETNA_UNSETTLED_LIMIT")
            }),
            forcedInclusionDelay: vm.envUint("FORCED_INCLUSION_DELAY"),
            maxAnchorAge: vm.envUint("MAX_ANCHOR_AGE")
        });
        return abi.encodeCall(EtnaInbox.init, (params));
    }

    /// @dev Reads an environment integer and rejects values outside uint64.
    /// @param _name The variable name.
    /// @return The uint64 value.
    function _envUint64(string memory _name) private view returns (uint64) {
        return SafeCast.toUint64(vm.envUint(_name));
    }

    /// @dev Returns whether an optional variable holds a non-empty value, which the caller then
    /// parses strictly. `vm.envOr` would also return its default for a malformed value.
    /// @param _name The variable name.
    /// @return Whether the variable is set and non-empty.
    function _isSet(string memory _name) private view returns (bool) {
        return vm.envExists(_name) && bytes(vm.envString(_name)).length != 0;
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    /// @notice PRIVATE_KEY is zero.
    error InvalidPrivateKey();
    /// @notice L1_CHAIN_ID is not this chain's id.
    error L1ChainIdMismatch();
    /// @notice ETNA_PROOF_VERIFIER has no code.
    error ProofVerifierHasNoCode();
}
