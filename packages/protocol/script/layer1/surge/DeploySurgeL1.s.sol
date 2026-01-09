// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EmptyImpl } from "./common/EmptyImpl.sol";
import { ProofVerifierDummy } from "./common/ProofVerifierDummy.sol";
import {
    Ownable2StepUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import {
    ControlID,
    RiscZeroGroth16Verifier
} from "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import { SP1Verifier as SuccinctVerifier } from "@sp1-contracts/src/v5.0.0/SP1VerifierPlonk.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { PreconfWhitelist } from "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { SurgeTimelockController } from "src/layer1/surge/SurgeTimelockController.sol";
import { SurgeVerifier } from "src/layer1/surge/SurgeVerifier.sol";
import { SurgeInbox } from "src/layer1/surge/deployments/internal-devnet/SurgeInbox.sol";
import { LibProofBitmap } from "src/layer1/surge/libs/LibProofBitmap.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { BridgedERC1155 } from "src/shared/vault/BridgedERC1155.sol";
import { BridgedERC20 } from "src/shared/vault/BridgedERC20.sol";
import { BridgedERC721 } from "src/shared/vault/BridgedERC721.sol";
import { ERC1155Vault } from "src/shared/vault/ERC1155Vault.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";
import { ERC721Vault } from "src/shared/vault/ERC721Vault.sol";
import { DeployCapability } from "test/shared/DeployCapability.sol";

/// @title DeploySurgeL1
/// @notice This script deploys the Surge protocol on L1.
/// @custom:security-contact security@nethermind.io
contract DeploySurgeL1 is DeployCapability {
    uint256 internal constant ADDRESS_LENGTH = 40;

    // Signer configuration
    // ---------------------------------------------------------------
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    // Owner configuration
    // ---------------------------------------------------------------
    address internal immutable contractOwner = vm.envAddress("CONTRACT_OWNER");

    // L2 configuration
    // ---------------------------------------------------------------
    uint64 internal immutable l2ChainId = uint64(vm.envUint("L2_CHAIN_ID"));

    // Verifier Configuration
    // ---------------------------------------------------------------
    bool internal immutable useDummyVerifier = vm.envBool("USE_DUMMY_VERIFIER");
    address internal immutable dummyVerifierSigner = vm.envAddress("DUMMY_VERIFIER_SIGNER");
    bool internal immutable deployRisc0RethVerifier = vm.envBool("DEPLOY_RISC0_RETH_VERIFIER");
    bool internal immutable deploySp1RethVerifier = vm.envBool("DEPLOY_SP1_RETH_VERIFIER");

    // Inbox configuration
    // ---------------------------------------------------------------
    uint48 internal immutable provingWindow = uint48(vm.envUint("PROVING_WINDOW"));
    uint48 internal immutable maxProofSubmissionDelay =
        uint48(vm.envUint("MAX_PROOF_SUBMISSION_DELAY"));
    uint256 internal immutable ringBufferSize = vm.envUint("RING_BUFFER_SIZE");
    uint8 internal immutable basefeeSharingPctg = uint8(vm.envUint("BASEFEE_SHARING_PCTG"));
    uint256 internal immutable minForcedInclusionCount = vm.envUint("MIN_FORCED_INCLUSION_COUNT");
    uint16 internal immutable forcedInclusionDelay = uint16(vm.envUint("FORCED_INCLUSION_DELAY"));
    uint64 internal immutable forcedInclusionFeeInGwei =
        uint64(vm.envUint("FORCED_INCLUSION_FEE_IN_GWEI"));
    uint64 internal immutable forcedInclusionFeeDoubleThreshold =
        uint64(vm.envUint("FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD"));
    uint16 internal immutable minCheckpointDelay = uint16(vm.envUint("MIN_CHECKPOINT_DELAY"));
    uint8 internal immutable permissionlessInclusionMultiplier =
        uint8(vm.envUint("PERMISSIONLESS_INCLUSION_MULTIPLIER"));

    // Finalization streak configuration
    // ---------------------------------------------------------------
    uint48 internal immutable maxFinalizationDelayBeforeStreakReset =
        uint48(vm.envUint("MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET"));

    // Rollback configuration
    // ---------------------------------------------------------------
    uint48 internal immutable maxFinalizationDelayBeforeRollback =
        uint48(vm.envUint("MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK"));

    // SurgeVerifier configuration
    // ---------------------------------------------------------------
    uint8 internal immutable numProofsThreshold = uint8(vm.envUint("NUM_PROOFS_THRESHOLD"));

    // Timelock configuration
    // ---------------------------------------------------------------
    bool internal immutable useTimelock = vm.envBool("USE_TIMELOCK");
    uint256 internal immutable timelockMinDelay = vm.envUint("TIMELOCK_MIN_DELAY");
    uint48 internal immutable timelockMinFinalizationStreak =
        uint48(vm.envUint("TIMELOCK_MIN_FINALIZATION_STREAK"));
    address[] internal timelockProposers = vm.envAddress("TIMELOCK_PROPOSERS", ",");
    address[] internal timelockExecutors = vm.envAddress("TIMELOCK_EXECUTORS", ",");

    struct SharedContracts {
        address sharedResolver;
        address signalService;
        address bridge;
        address erc20Vault;
        address erc721Vault;
        address erc1155Vault;
    }

    struct RollupContracts {
        address proofVerifier;
        address inbox;
    }

    struct VerifierContracts {
        address risc0RethVerifier;
        address sp1RethVerifier;
    }

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(l2ChainId != block.chainid || l2ChainId != 0, "config: L2_CHAIN_ID");
        require(contractOwner != address(0), "config: CONTRACT_OWNER");

        console2.log("** Contract owner: ", contractOwner);

        // Empty implementation for temporary use
        address emptyImpl = address(new EmptyImpl());
        writeJson("empty_impl", emptyImpl);

        // Deploy rollup contracts (inbox proxy and proof verifier)
        // SurgeVerifier needs verifiers set after construction
        // ---------------------------------------------------------------
        RollupContracts memory rollupContracts = deployRollupContracts(emptyImpl);

        // Deploy timelock controller if enabled
        // The timelock becomes the effective owner of all contracts
        // ---------------------------------------------------------------
        address effectiveOwner = contractOwner;
        if (useTimelock) {
            effectiveOwner = deployTimelock(rollupContracts);
            console2.log("** Effective owner (timelock):", effectiveOwner);
        }

        // Deploy internal verifiers (needed for SurgeVerifier)
        // ---------------------------------------------------------------
        VerifierContracts memory verifierContracts = deployInternalVerifiers(effectiveOwner);

        // Deploy shared contracts
        // ---------------------------------------------------------------
        SharedContracts memory sharedContracts =
            deploySharedContracts(effectiveOwner, rollupContracts);

        // Register L2 addresses in the resolver
        setupSharedResolver(sharedContracts, effectiveOwner);

        // Setup proof verifier with internal verifiers
        // ---------------------------------------------------------------
        setupProofVerifier(rollupContracts, verifierContracts, effectiveOwner);

        // Deploy inbox implementation
        // ---------------------------------------------------------------
        setupInbox(rollupContracts, sharedContracts, effectiveOwner);

        // Verify deployment
        // ---------------------------------------------------------------
        verifyDeployment(sharedContracts, rollupContracts, verifierContracts, effectiveOwner);

        console2.log("=====================================");
        console2.log("Surge L1 Deployment Complete");
        console2.log("=====================================");
    }

    function deploySharedContracts(
        address _owner,
        RollupContracts memory _rollupContracts
    )
        internal
        returns (SharedContracts memory sharedContracts)
    {
        // Deploy shared resolver
        // ---------------------------------------------------------------
        sharedContracts.sharedResolver = deployProxy({
            name: "shared_resolver",
            impl: address(new DefaultResolver()),
            // Owner is initially the deployer contract because we need to register the contracts
            data: abi.encodeCall(DefaultResolver.init, (address(0)))
        });

        // Deploy signal service
        // ---------------------------------------------------------------
        sharedContracts.signalService = deployProxy({
            name: "signal_service",
            impl: address(new SignalService(_rollupContracts.inbox, getL2SignalServiceAddress())),
            data: abi.encodeCall(SignalService.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        // Deploy bridge
        // ---------------------------------------------------------------
        sharedContracts.bridge = deployProxy({
            name: "bridge",
            impl: address(
                new Bridge(address(sharedContracts.sharedResolver), sharedContracts.signalService)
            ),
            data: abi.encodeCall(Bridge.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        // Deploy Vaults
        // ---------------------------------------------------------------
        sharedContracts.erc20Vault = deployProxy({
            name: "erc20_vault",
            impl: address(new ERC20Vault(address(sharedContracts.sharedResolver))),
            data: abi.encodeCall(ERC20Vault.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        sharedContracts.erc721Vault = deployProxy({
            name: "erc721_vault",
            impl: address(new ERC721Vault(address(sharedContracts.sharedResolver))),
            data: abi.encodeCall(ERC721Vault.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        sharedContracts.erc1155Vault = deployProxy({
            name: "erc1155_vault",
            impl: address(new ERC1155Vault(address(sharedContracts.sharedResolver))),
            data: abi.encodeCall(ERC1155Vault.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        // Deploy Bridged token implementations (clone pattern)
        // ---------------------------------------------------------------
        address bridgedErc20 = address(new BridgedERC20(sharedContracts.erc20Vault));
        register(sharedContracts.sharedResolver, "bridged_erc20", bridgedErc20);
        writeJson("bridged_erc20", bridgedErc20);

        address bridgedErc721 = address(new BridgedERC721(address(sharedContracts.erc721Vault)));
        register(sharedContracts.sharedResolver, "bridged_erc721", bridgedErc721);
        writeJson("bridged_erc721", bridgedErc721);

        address bridgedErc1155 = address(new BridgedERC1155(address(sharedContracts.erc1155Vault)));
        register(sharedContracts.sharedResolver, "bridged_erc1155", bridgedErc1155);
        writeJson("bridged_erc1155", bridgedErc1155);
    }

    function deployRollupContracts(address _emptyImpl)
        internal
        returns (RollupContracts memory rollupContracts)
    {
        // Deploy inbox proxy
        // ---------------------------------------------------------------
        rollupContracts.inbox = deployProxy({ name: "surge_inbox", impl: _emptyImpl, data: "" });

        // Deploy proof verifier (SurgeVerifier)
        // Verifiers are set after construction via setVerifier
        // The deployer is the initial owner so that we can set the internal verifiers later on.
        // ---------------------------------------------------------------
        rollupContracts.proofVerifier =
            address(new SurgeVerifier(rollupContracts.inbox, numProofsThreshold, msg.sender));
        console2.log("** Deployed SurgeVerifier:", rollupContracts.proofVerifier);
        writeJson("surge_verifier", rollupContracts.proofVerifier);
    }

    function deployTimelock(RollupContracts memory _rollupContracts)
        internal
        returns (address timelock)
    {
        require(timelockMinDelay > 0, "config: TIMELOCK_MIN_DELAY");
        require(timelockMinFinalizationStreak > 0, "config: TIMELOCK_MIN_FINALIZATION_STREAK");
        require(timelockProposers.length > 0, "config: TIMELOCK_PROPOSERS");
        require(timelockExecutors.length > 0, "config: TIMELOCK_EXECUTORS");

        timelock = address(
            new SurgeTimelockController(
                _rollupContracts.inbox,
                _rollupContracts.proofVerifier,
                timelockMinFinalizationStreak,
                timelockMinDelay,
                timelockProposers,
                timelockExecutors
            )
        );
        writeJson("surge_timelock", timelock);
        console2.log("** Deployed SurgeTimelockController:", timelock);
    }

    /// @dev The deployer is the initial owner of the internal verifiers
    /// Ownership is transferred to the effective owner and must be accepted
    function deployInternalVerifiers(address _owner)
        private
        returns (VerifierContracts memory verifierContracts)
    {
        // When using dummy verifier, deploy a single ProofVerifierDummy for all internal verifiers
        if (useDummyVerifier) {
            require(dummyVerifierSigner != address(0), "config: DUMMY_VERIFIER_SIGNER");

            ProofVerifierDummy dummyVerifier = new ProofVerifierDummy(dummyVerifierSigner);
            address dummyAddr = address(dummyVerifier);
            writeJson("proof_verifier_dummy", dummyAddr);
            console2.log("** Deployed ProofVerifierDummy:", dummyAddr);
            console2.log("** ProofVerifierDummy signer:", dummyVerifierSigner);

            // Use the same dummy for all enabled verifiers
            if (deployRisc0RethVerifier) {
                verifierContracts.risc0RethVerifier = dummyAddr;
                console2.log("** Using ProofVerifierDummy for RISC0");
            }
            if (deploySp1RethVerifier) {
                verifierContracts.sp1RethVerifier = dummyAddr;
                console2.log("** Using ProofVerifierDummy for SP1");
            }
        } else {
            // Deploy actual verifiers when not using dummy
            if (deployRisc0RethVerifier) {
                RiscZeroGroth16Verifier verifier =
                    new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);
                writeJson("risc0_groth16_verifier", address(verifier));
                console2.log("** Deployed Risc0 groth16 verifier: ", address(verifier));

                Risc0Verifier risc0Verifier =
                    new Risc0Verifier(l2ChainId, address(verifier), msg.sender);
                verifierContracts.risc0RethVerifier = address(risc0Verifier);
                writeJson("risc0_verifier", address(risc0Verifier));
                console2.log("** Deployed Risc0 verifier: ", address(risc0Verifier));

                // Transfer ownership (requires acceptance)
                risc0Verifier.transferOwnership(_owner);
                console2.log("** Risc0 verifier ownership transfer initiated to:", _owner);
            }

            if (deploySp1RethVerifier) {
                SuccinctVerifier succinctVerifier = new SuccinctVerifier();
                writeJson("succinct_verifier", address(succinctVerifier));
                console2.log("** Deployed Succint verifier: ", address(succinctVerifier));

                SP1Verifier sp1Verifier =
                    new SP1Verifier(l2ChainId, address(succinctVerifier), msg.sender);
                verifierContracts.sp1RethVerifier = address(sp1Verifier);
                writeJson("sp1_verifier", address(sp1Verifier));
                console2.log("** Deployed SP1 verifier: ", address(sp1Verifier));

                // Transfer ownership (requires acceptance)
                sp1Verifier.transferOwnership(_owner);
                console2.log("** SP1 verifier ownership transfer initiated to:", _owner);
            }
        }
    }

    function setupSharedResolver(
        SharedContracts memory _sharedContracts,
        address _owner
    )
        internal
    {
        // Register L2 addresses
        // ---------------------------------------------------------------
        register(
            _sharedContracts.sharedResolver,
            "signal_service",
            getL2SignalServiceAddress(),
            l2ChainId
        );
        register(_sharedContracts.sharedResolver, "bridge", getL2BridgeAddress(), l2ChainId);
        register(
            _sharedContracts.sharedResolver, "erc20_vault", getL2Erc20VaultAddress(), l2ChainId
        );
        register(
            _sharedContracts.sharedResolver, "erc721_vault", getL2Erc721VaultAddress(), l2ChainId
        );
        register(
            _sharedContracts.sharedResolver, "erc1155_vault", getL2Erc1155VaultAddress(), l2ChainId
        );

        // Requires ownership acceptance
        DefaultResolver(_sharedContracts.sharedResolver).transferOwnership(_owner);
        console2.log("** SharedResolver ownership transfer initiated to:", _owner);
    }

    function setupProofVerifier(
        RollupContracts memory _rollupContracts,
        VerifierContracts memory _verifierContracts,
        address _owner
    )
        internal
    {
        SurgeVerifier proofVerifier = SurgeVerifier(_rollupContracts.proofVerifier);

        // Set internal verifiers based on which were deployed
        // Proof bit flags from SurgeVerifier: RISC0_RETH = 1, SP1_RETH = 2
        if (_verifierContracts.risc0RethVerifier != address(0)) {
            proofVerifier.setVerifier(
                LibProofBitmap.ProofBitmap.wrap(proofVerifier.RISC0_RETH()),
                _verifierContracts.risc0RethVerifier
            );
            console2.log("** Set RISC0 verifier:", _verifierContracts.risc0RethVerifier);
        }

        if (_verifierContracts.sp1RethVerifier != address(0)) {
            proofVerifier.setVerifier(
                LibProofBitmap.ProofBitmap.wrap(proofVerifier.SP1_RETH()),
                _verifierContracts.sp1RethVerifier
            );
            console2.log("** Set SP1 verifier:", _verifierContracts.sp1RethVerifier);
        }

        // Requires ownership acceptance
        proofVerifier.transferOwnership(_owner);
        console2.log("** Proof verifier ownership transfer initiated to:", _owner);
    }

    function setupInbox(
        RollupContracts memory _rollupContracts,
        SharedContracts memory _sharedContracts,
        address _owner
    )
        internal
    {
        // Deploy whitelist
        address whitelist = deployProxy({
            name: "preconf_whitelist",
            impl: address(new PreconfWhitelist()),
            data: abi.encodeCall(PreconfWhitelist.init, (_owner))
        });

        // Build inbox configuration
        IInbox.Config memory config = IInbox.Config({
            proofVerifier: _rollupContracts.proofVerifier,
            proposerChecker: whitelist,
            proverWhitelist: address(0), // No prover whitelist
            signalService: _sharedContracts.signalService,
            provingWindow: provingWindow,
            maxProofSubmissionDelay: maxProofSubmissionDelay,
            ringBufferSize: ringBufferSize,
            basefeeSharingPctg: basefeeSharingPctg,
            minForcedInclusionCount: minForcedInclusionCount,
            forcedInclusionDelay: forcedInclusionDelay,
            forcedInclusionFeeInGwei: forcedInclusionFeeInGwei,
            forcedInclusionFeeDoubleThreshold: forcedInclusionFeeDoubleThreshold,
            minCheckpointDelay: minCheckpointDelay,
            permissionlessInclusionMultiplier: permissionlessInclusionMultiplier
        });

        // Deploy inbox implementation (SurgeInbox with rollback and finalization streak features)
        address inboxImpl = address(
            new SurgeInbox(
                config, maxFinalizationDelayBeforeStreakReset, maxFinalizationDelayBeforeRollback
            )
        );
        console2.log("** Deployed SurgeInbox implementation: ", inboxImpl);
        writeJson("surge_inbox_impl", inboxImpl);

        // Upgrade inbox proxy to actual implementation
        UUPSUpgradeable(_rollupContracts.inbox).upgradeTo(inboxImpl);

        // Initialize inbox
        SurgeInbox(payable(_rollupContracts.inbox)).init(msg.sender);
        console2.log("** SurgeInbox initialized");

        // Requires ownership acceptance
        Ownable2StepUpgradeable(_rollupContracts.inbox).transferOwnership(_owner);
        console2.log("** Inbox ownership transfer initiated to:", _owner);
    }

    function verifyDeployment(
        SharedContracts memory _sharedContracts,
        RollupContracts memory _rollupContracts,
        VerifierContracts memory _verifierContracts,
        address _expectedOwner
    )
        internal
        view
    {
        // Verify L1 registrations
        // ---------------------------------------------------------------
        verifyL1Registrations(_sharedContracts.sharedResolver);

        // Verify L2 registrations
        // ---------------------------------------------------------------
        verifyL2Registrations(_sharedContracts.sharedResolver);

        // Build list of contracts where owner is already set
        // ---------------------------------------------------------------
        address[] memory ownerContracts = new address[](5);
        ownerContracts[0] = _sharedContracts.signalService;
        ownerContracts[1] = _sharedContracts.bridge;
        ownerContracts[2] = _sharedContracts.erc20Vault;
        ownerContracts[3] = _sharedContracts.erc721Vault;
        ownerContracts[4] = _sharedContracts.erc1155Vault;

        // Build list of contracts with pending ownership transfer
        // SurgeVerifier has ownership for setVerifier functionality
        // Note: Internal verifiers (risc0, sp1) are only added when not using dummy
        // as ProofVerifierDummy doesn't have Ownable2Step
        // ---------------------------------------------------------------
        address[] memory pendingOwnerContracts;
        if (useDummyVerifier) {
            pendingOwnerContracts = new address[](3);
            pendingOwnerContracts[0] = _rollupContracts.proofVerifier;
            pendingOwnerContracts[1] = _rollupContracts.inbox;
            pendingOwnerContracts[2] = _sharedContracts.sharedResolver;
        } else {
            pendingOwnerContracts = new address[](5);
            pendingOwnerContracts[0] = _rollupContracts.proofVerifier;
            pendingOwnerContracts[1] = _rollupContracts.inbox;
            pendingOwnerContracts[2] = _sharedContracts.sharedResolver;
            pendingOwnerContracts[3] = _verifierContracts.risc0RethVerifier; // May be address(0)
            pendingOwnerContracts[4] = _verifierContracts.sp1RethVerifier; // May be address(0)
        }

        // Verify ownership
        // ---------------------------------------------------------------
        verifyOwnership(ownerContracts, pendingOwnerContracts, _expectedOwner);

        console2.log("** Deployment verified **");
    }

    function verifyL1Registrations(address _sharedResolver) internal view {
        bytes32[] memory sharedNames = new bytes32[](8);
        sharedNames[0] = bytes32("signal_service");
        sharedNames[1] = bytes32("bridge");
        sharedNames[2] = bytes32("erc20_vault");
        sharedNames[3] = bytes32("erc721_vault");
        sharedNames[4] = bytes32("erc1155_vault");
        sharedNames[5] = bytes32("bridged_erc20");
        sharedNames[6] = bytes32("bridged_erc721");
        sharedNames[7] = bytes32("bridged_erc1155");

        // Get addresses from shared resolver
        address[] memory sharedAddresses = new address[](sharedNames.length);
        for (uint256 i = 0; i < sharedNames.length; i++) {
            try DefaultResolver(_sharedResolver)
                .resolve(block.chainid, sharedNames[i], false) returns (
                address addr
            ) {
                sharedAddresses[i] = addr;
            } catch {
                revert(
                    string.concat(
                        "verifyL1Registrations: missing registration for ",
                        Strings.toHexString(uint256(sharedNames[i]))
                    )
                );
            }
        }
    }

    function verifyL2Registrations(address _sharedResolver) internal view {
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("signal_service"), false)
                == getL2SignalServiceAddress(),
            "verifyL2Registrations: signal_service mismatch"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("bridge"), false)
                == getL2BridgeAddress(),
            "verifyL2Registrations: bridge mismatch"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("erc20_vault"), false)
                == getL2Erc20VaultAddress(),
            "verifyL2Registrations: erc20_vault mismatch"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("erc721_vault"), false)
                == getL2Erc721VaultAddress(),
            "verifyL2Registrations: erc721_vault mismatch"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("erc1155_vault"), false)
                == getL2Erc1155VaultAddress(),
            "verifyL2Registrations: erc1155_vault mismatch"
        );

        console2.log("** L2 registrations verified **");
    }

    function verifyOwnership(
        address[] memory _ownerContracts,
        address[] memory _pendingOwnerContracts,
        address _expectedOwner
    )
        internal
        view
    {
        // Verify current ownership for contracts without pending ownership transfer
        for (uint256 i; i < _ownerContracts.length; ++i) {
            if (_ownerContracts[i] == address(0)) {
                continue;
            }

            address currentOwner = Ownable2StepUpgradeable(_ownerContracts[i]).owner();
            require(
                currentOwner == _expectedOwner,
                string.concat(
                    "verifyOwnership: ", Strings.toHexString(uint160(_ownerContracts[i]), 20)
                )
            );
        }

        // Verify pending ownership for contracts with pending ownership transfer
        for (uint256 i; i < _pendingOwnerContracts.length; ++i) {
            if (_pendingOwnerContracts[i] == address(0)) {
                continue;
            }

            address pendingOwner = Ownable2StepUpgradeable(_pendingOwnerContracts[i]).pendingOwner();
            require(
                pendingOwner == _expectedOwner,
                string.concat(
                    "verifyPendingOwnership: ",
                    Strings.toHexString(uint160(_pendingOwnerContracts[i]), 20)
                )
            );
        }
    }

    // ---------------------------------------------------------------
    // L2 Address Getters
    // ---------------------------------------------------------------

    function getL2BridgeAddress() internal view returns (address) {
        return getConstantAddress(vm.toString(l2ChainId), "1");
    }

    function getL2Erc20VaultAddress() internal view returns (address) {
        return getConstantAddress(vm.toString(l2ChainId), "2");
    }

    function getL2Erc721VaultAddress() internal view returns (address) {
        return getConstantAddress(vm.toString(l2ChainId), "3");
    }

    function getL2Erc1155VaultAddress() internal view returns (address) {
        return getConstantAddress(vm.toString(l2ChainId), "4");
    }

    function getL2SignalServiceAddress() internal view returns (address) {
        return getConstantAddress(vm.toString(l2ChainId), "5");
    }

    // ---------------------------------------------------------------
    // Utilities
    // ---------------------------------------------------------------

    function getConstantAddress(
        string memory prefix,
        string memory suffix
    )
        internal
        pure
        returns (address)
    {
        bytes memory prefixBytes = bytes(prefix);
        bytes memory suffixBytes = bytes(suffix);

        require(
            prefixBytes.length + suffixBytes.length <= ADDRESS_LENGTH, "Prefix + suffix too long"
        );

        // Create the middle padding of zeros
        uint256 paddingLength = ADDRESS_LENGTH - prefixBytes.length - suffixBytes.length;
        bytes memory padding = new bytes(paddingLength);
        for (uint256 i = 0; i < paddingLength; i++) {
            padding[i] = "0";
        }

        // Concatenate the parts
        string memory hexString = string(abi.encodePacked("0x", prefix, string(padding), suffix));

        return vm.parseAddress(hexString);
    }

    /// @dev Writes an address to the deployment JSON file
    function writeJson(string memory name, address addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/deploy_l1.json")
        );
    }
}
