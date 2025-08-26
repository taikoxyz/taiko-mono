// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// OpenZeppelin
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Third-party verifiers
import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import { SP1Verifier as SuccinctVerifier } from
    "@sp1-contracts/src/v4.0.0-rc.3/SP1VerifierPlonk.sol";
import "@p256-verifier/contracts/P256Verifier.sol";

// Shared contracts
import "src/shared/common/DefaultResolver.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/tokenvault/BridgedERC20.sol";
import "src/shared/tokenvault/BridgedERC721.sol";

// Layer1 contracts
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/EnclaveIdStruct.sol";
import "src/layer1/automata-attestation/lib/TCBInfoStruct.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/lib/QuoteV3Auth/V3Struct.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";
import "src/layer1/based/TaikoInbox.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";
import "src/layer1/forced-inclusion/TaikoWrapper.sol";
import "src/layer1/forced-inclusion/ForcedInclusionStore.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/verifiers/SgxVerifier.sol";

// Surge contracts
import "src/layer1/surge/SurgeDevnetInbox.sol";
import "src/layer1/surge/SurgeHoodiInbox.sol";
import "src/layer1/surge/SurgeMainnetInbox.sol";
import "src/layer1/surge/bridge/SurgeBridge.sol";
import "src/layer1/surge/bridge/SurgeERC20Vault.sol";
import "src/layer1/surge/bridge/SurgeERC721Vault.sol";
import "src/layer1/surge/bridge/SurgeERC1155Vault.sol";
import "src/layer1/surge/bridge/SurgeSignalService.sol";
import "src/layer1/surge/verifiers/SurgeVerifier.sol";

// Local imports
import "./common/EmptyImpl.sol";
import "./common/AttestationLib.sol";
import "test/shared/DeployCapability.sol";

// Named imports to prevent conflicts
import { SurgeTimelockController } from "src/layer1/surge/common/SurgeTimelockController.sol";

/// @title DeploySurgeL1
/// @notice This script deploys the core Taiko protocol modified for Nethermind's Surge.
contract DeploySurgeL1 is DeployCapability {
    uint256 internal constant ADDRESS_LENGTH = 40;

    // Deployment configuration
    // ---------------------------------------------------------------
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    // Timelock configuration
    // ---------------------------------------------------------------
    bool internal immutable useTimelockedOwner = vm.envBool("USE_TIMELOCKED_OWNER");
    uint256 internal immutable timelockPeriod = uint64(vm.envUint("TIMELOCK_PERIOD"));
    address internal immutable ownerMultisig = vm.envAddress("OWNER_MULTISIG");

    // DAO configuration
    // ---------------------------------------------------------------
    address internal immutable dao = vm.envAddress("DAO");

    // L2 configuration
    // ---------------------------------------------------------------
    uint64 internal immutable l2ChainId = uint64(vm.envUint("L2_CHAINID"));
    bytes32 internal immutable l2GenesisHash = vm.envBytes32("L2_GENESIS_HASH");

    // Liveness configuration
    // ---------------------------------------------------------------
    uint64 internal immutable maxVerificationDelay = uint64(vm.envUint("MAX_VERIFICATION_DELAY"));
    uint64 internal immutable minVerificationStreak = uint64(vm.envUint("MIN_VERIFICATION_STREAK"));
    uint96 internal immutable livenessBondBase = uint96(vm.envUint("LIVENESS_BOND_BASE"));
    uint24 internal immutable cooldownWindow = uint24(vm.envUint("COOLDOWN_WINDOW"));

    // Preconf configuration
    // ---------------------------------------------------------------
    bool internal immutable usePreconf = vm.envBool("USE_PRECONF");
    address internal immutable fallbackPreconf = vm.envOr("FALLBACK_PRECONF", address(0));

    // Forced inclusion configuration
    // ---------------------------------------------------------------
    uint8 internal immutable inclusionWindow = uint8(vm.envUint("INCLUSION_WINDOW"));
    uint64 internal immutable inclusionFeeInGwei = uint64(vm.envUint("INCLUSION_FEE_IN_GWEI"));

    // Verifier configuration
    // ---------------------------------------------------------------
    bool internal immutable shouldSetupVerifiers = vm.envBool("SHOULD_SETUP_VERIFIERS");

    // Risc0 verifier trusted image IDs
    bytes32 internal immutable risc0BlockProvingImageId =
        vm.envBytes32("RISC0_BLOCK_PROVING_IMAGE_ID");
    bytes32 internal immutable risc0AggregationImageId = vm.envBytes32("RISC0_AGGREGATION_IMAGE_ID");

    // SP1 verifier trusted program verification keys
    bytes32 internal immutable sp1BlockProvingProgramVKey =
        vm.envBytes32("SP1_BLOCK_PROVING_PROGRAM_VKEY");
    bytes32 internal immutable sp1AggregationProgramVKey =
        vm.envBytes32("SP1_AGGREGATION_PROGRAM_VKEY");

    // SGX verifier configuration
    bytes32 internal immutable mrEnclave = vm.envBytes32("MR_ENCLAVE");
    bytes32 internal immutable mrSigner = vm.envBytes32("MR_SIGNER");

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
        address taikoInbox;
    }

    struct VerifierContracts {
        address sgxRethVerifier;
        address risc0RethVerifier;
        address sp1RethVerifier;
        address automataProxy;
        address pemCertChainLibAddr;
    }

    struct WrapperContracts {
        address forcedInclusionStore;
        address taikoWrapper;
        address preconfWhitelist;
        address preconfRouter;
    }

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(l2ChainId != block.chainid || l2ChainId != 0, "config: L2_CHAIN_ID");
        require(l2GenesisHash != bytes32(0), "config: L2_GENESIS_HASH");
        require(maxVerificationDelay != 0, "config: MAX_VERIFICATION_DELAY");
        require(minVerificationStreak != 0, "config: MIN_LIVENESS_STREAK");
        require(livenessBondBase != 0, "config: LIVENESS_BOND_BASE");
        require(cooldownWindow != 0, "config: COOLDOWN_WINDOW");
        require(
            cooldownWindow < maxVerificationDelay,
            "config: COOLDOWN_WINDOW < MAX_VERIFICATION_DELAY"
        );
        address l1Owner = msg.sender;

        // Timelock variables
        address[] memory executors;
        address[] memory proposers;

        if (useTimelockedOwner) {
            require(ownerMultisig != address(0), "config: OWNER_MULTISIG");

            // Deploy timelock controller
            // ---------------------------------------------------------------

            // Array built via env can only be in memory
            address[] memory ownerMultisigSigners = vm.envAddress("OWNER_MULTISIG_SIGNERS", ",");
            require(ownerMultisigSigners.length > 0, "Config: OWNER_MULTISIG_SIGNERS");
            for (uint256 i = 0; i < ownerMultisigSigners.length; i++) {
                require(ownerMultisigSigners[i] != address(0), "Config: OWNER_MULTISIG_SIGNERS");
            }

            executors = ownerMultisigSigners;

            proposers = new address[](1);
            proposers[0] = ownerMultisig;

            // The timelock controller will serve as the owner of all the surge contracts
            l1Owner = deployTimelockController();
        }
        writeJson("l1_owner", l1Owner);
        console2.log("** L1 owner: ", l1Owner);

        // Deploy shared contracts
        // ---------------------------------------------------------------
        SharedContracts memory sharedContracts = deploySharedContracts(l1Owner);

        // Empty implementation for temporary use
        address emptyImpl = address(new EmptyImpl());

        // Deploy rollup contracts
        // ---------------------------------------------------------------
        RollupContracts memory rollupContracts =
            deployRollupContracts(emptyImpl, sharedContracts.sharedResolver);

        // Deploy verifiers
        // ---------------------------------------------------------------
        VerifierContracts memory verifiers =
            deployVerifiers(rollupContracts.proofVerifier, rollupContracts.taikoInbox);

        UUPSUpgradeable(rollupContracts.proofVerifier).upgradeTo({
            newImplementation: address(new SurgeVerifier(rollupContracts.taikoInbox))
        });

        // Signal service need to authorize the new rollup
        // ---------------------------------------------------------------
        SignalService signalService = SignalService(sharedContracts.signalService);

        SignalService(sharedContracts.signalService).authorize(rollupContracts.taikoInbox, true);
        signalService.transferOwnership(l1Owner);

        {
            // Build L2 addresses
            // ---------------------------------------------------------------
            address l2BridgeAddress = getConstantAddress(vm.toString(l2ChainId), "1");
            address l2Erc20VaultAddress = getConstantAddress(vm.toString(l2ChainId), "2");
            address l2Erc721VaultAddress = getConstantAddress(vm.toString(l2ChainId), "3");
            address l2Erc1155VaultAddress = getConstantAddress(vm.toString(l2ChainId), "4");
            address l2SignalServiceAddress = getConstantAddress(vm.toString(l2ChainId), "5");

            // Register L2 addresses
            // ---------------------------------------------------------------
            register(
                sharedContracts.sharedResolver, "signal_service", l2SignalServiceAddress, l2ChainId
            );
            register(sharedContracts.sharedResolver, "bridge", l2BridgeAddress, l2ChainId);
            register(sharedContracts.sharedResolver, "erc20_vault", l2Erc20VaultAddress, l2ChainId);
            register(
                sharedContracts.sharedResolver, "erc721_vault", l2Erc721VaultAddress, l2ChainId
            );
            register(
                sharedContracts.sharedResolver, "erc1155_vault", l2Erc1155VaultAddress, l2ChainId
            );
        }

        // Deploy wrapper contracts
        // ---------------------------------------------------------------
        WrapperContracts memory wrapperContracts =
            deployWrapperContracts(l1Owner, rollupContracts.taikoInbox, emptyImpl);

        // Deploy fork router
        // ---------------------------------------------------------------
        deployForkRouter(
            wrapperContracts.taikoWrapper,
            rollupContracts.proofVerifier,
            sharedContracts.signalService,
            rollupContracts.taikoInbox
        );

        // Setup verifiers
        // ---------------------------------------------------------------
        if (shouldSetupVerifiers) {
            setupVerifiers(verifiers);
        }

        // Initialise and transfer ownership to either the timelock controller or the deployer
        // -----------------------------------------------------------------------------------
        if (useTimelockedOwner) {
            SurgeTimelockController(payable(l1Owner)).init(
                timelockPeriod,
                proposers,
                executors,
                rollupContracts.taikoInbox,
                rollupContracts.proofVerifier,
                minVerificationStreak
            );
            console2.log("** timelockController initialised");
        }

        SgxVerifier(verifiers.sgxRethVerifier).transferOwnership(l1Owner);
        console2.log("** sgxRethVerifier ownership transferred to:", l1Owner);

        Risc0Verifier(verifiers.risc0RethVerifier).transferOwnership(l1Owner);
        console2.log("** risc0RethVerifier ownership transferred to:", l1Owner);

        SP1Verifier(verifiers.sp1RethVerifier).transferOwnership(l1Owner);
        console2.log("** sp1RethVerifier ownership transferred to:", l1Owner);

        AutomataDcapV3Attestation(verifiers.automataProxy).transferOwnership(l1Owner);
        console2.log("** automataProxy ownership transferred to:", l1Owner);

        TaikoInbox(payable(rollupContracts.taikoInbox)).init(l1Owner, l2GenesisHash);
        console2.log("** taikoInbox initialised and ownership transferred to:", l1Owner);

        SurgeVerifier(rollupContracts.proofVerifier).init(
            l1Owner,
            verifiers.sgxRethVerifier,
            address(0), // TDX Reth verifier is not deployed yet
            verifiers.risc0RethVerifier,
            verifiers.sp1RethVerifier
        );
        console2.log("** proofVerifier initialised and ownership transferred to:", l1Owner);

        ForcedInclusionStore(wrapperContracts.forcedInclusionStore).init(l1Owner);
        console2.log("** forcedInclusionStore initialised and ownership transferred to:", l1Owner);

        TaikoWrapper(wrapperContracts.taikoWrapper).init(l1Owner);
        console2.log("** taikoWrapper initialised and ownership transferred to:", l1Owner);

        DefaultResolver(sharedContracts.sharedResolver).transferOwnership(l1Owner);
        console2.log("** sharedResolver initialised and ownership transferred to:", l1Owner);

        // Verify deployment
        // ---------------------------------------------------------------
        verifyDeployment(
            sharedContracts,
            rollupContracts,
            wrapperContracts,
            verifiers,
            sharedContracts.sharedResolver,
            l1Owner
        );
    }

    function deployTimelockController() internal returns (address timelockController) {
        timelockController = deployProxy({
            name: "surge_timelock_controller",
            impl: address(new SurgeTimelockController()),
            data: ""
        });
    }

    function deploySharedContracts(address _owner)
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

        // Deploy bridging contracts
        // ---------------------------------------------------------------
        sharedContracts.signalService = deployProxy({
            name: "signal_service",
            impl: address(new SurgeSignalService(address(sharedContracts.sharedResolver))),
            // Owner is initially the deployer contract because we need to authorize Taiko Inbox
            // to sync chain data
            data: abi.encodeCall(SignalService.init, (address(0))),
            registerTo: sharedContracts.sharedResolver
        });

        address quotaManager = address(0);
        sharedContracts.bridge = deployProxy({
            name: "bridge",
            impl: address(
                new SurgeBridge(
                    address(sharedContracts.sharedResolver), sharedContracts.signalService, quotaManager
                )
            ),
            data: abi.encodeCall(Bridge.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        // Deploy Vaults
        // ---------------------------------------------------------------
        sharedContracts.erc20Vault = deployProxy({
            name: "erc20_vault",
            impl: address(new SurgeERC20Vault(address(sharedContracts.sharedResolver))),
            data: abi.encodeCall(ERC20Vault.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        sharedContracts.erc721Vault = deployProxy({
            name: "erc721_vault",
            impl: address(new SurgeERC721Vault(address(sharedContracts.sharedResolver))),
            data: abi.encodeCall(ERC721Vault.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        sharedContracts.erc1155Vault = deployProxy({
            name: "erc1155_vault",
            impl: address(new SurgeERC1155Vault(address(sharedContracts.sharedResolver))),
            data: abi.encodeCall(ERC1155Vault.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        // Deploy Bridged token implementations (clone pattern)
        // ---------------------------------------------------------------
        register(
            sharedContracts.sharedResolver,
            "bridged_erc20",
            address(new BridgedERC20(sharedContracts.erc20Vault))
        );
        register(
            sharedContracts.sharedResolver,
            "bridged_erc721",
            address(new BridgedERC721(address(sharedContracts.erc721Vault)))
        );
        register(
            sharedContracts.sharedResolver,
            "bridged_erc1155",
            address(new BridgedERC1155(address(sharedContracts.erc1155Vault)))
        );
    }

    function deployRollupContracts(
        address _emptyImpl,
        address _sharedResolver
    )
        internal
        returns (RollupContracts memory rollupContracts)
    {
        // Deploy proof verifier and inbox
        // ---------------------------------------------------------------
        rollupContracts.proofVerifier =
            deployProxy({ name: "proof_verifier", impl: _emptyImpl, data: "" });

        rollupContracts.taikoInbox =
            deployProxy({ name: "taiko", impl: _emptyImpl, data: "", registerTo: _sharedResolver });
    }

    function deployVerifiers(
        address _proofVerifier,
        address _taikoInbox
    )
        private
        returns (VerifierContracts memory verifiers)
    {
        // No need to proxy these, because they are 3rd party. If we want to modify, we simply
        // change the registerAddress("automata_dcap_attestation", address(attestation));
        SigVerifyLib sigVerifyLib = new SigVerifyLib(address(new P256Verifier()));
        PEMCertChainLib pemCertChainLib = new PEMCertChainLib();
        // Log addresses for the user to register sgx instance
        console2.log("SigVerifyLib", address(sigVerifyLib));
        console2.log("PemCertChainLib", address(pemCertChainLib));

        // Write sigVerifyLib and pemCertChainLib to json file
        writeJson("sig_verify_lib", address(sigVerifyLib));
        writeJson("pem_cert_chain_lib", address(pemCertChainLib));

        verifiers.pemCertChainLibAddr = address(pemCertChainLib);

        address automataDcapV3AttestationImpl = address(new AutomataDcapV3Attestation());
        verifiers.automataProxy = deployProxy({
            name: "automata_dcap_attestation",
            impl: automataDcapV3AttestationImpl,
            data: abi.encodeCall(
                AutomataDcapV3Attestation.init,
                // Owner is initially the deployer contract because we need to set the
                // mrSigner and mrEnclave
                (address(0), address(sigVerifyLib), address(pemCertChainLib))
            )
        });

        verifiers.sgxRethVerifier = deployProxy({
            name: "sgx_reth_verifier",
            impl: address(
                new SgxVerifier(l2ChainId, _taikoInbox, _proofVerifier, verifiers.automataProxy)
            ),
            // Owner is initially the deployer contract because we need to set the
            // instance
            data: abi.encodeCall(SgxVerifier.init, address(0))
        });

        (verifiers.risc0RethVerifier, verifiers.sp1RethVerifier) = deployZKVerifiers();
    }

    function deployZKVerifiers() private returns (address risc0Verifier, address sp1Verifier) {
        // Deploy r0 groth16 verifier
        RiscZeroGroth16Verifier verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);
        writeJson("risc0_groth16_verifier", address(verifier));
        console2.log("** Deployed Risc0 groth16 verifier: ", address(verifier));

        risc0Verifier = deployProxy({
            name: "risc0_reth_verifier",
            impl: address(new Risc0Verifier(l2ChainId, address(verifier))),
            // Owner is initially the deployer contract because we need to set the
            // image ids
            data: abi.encodeCall(Risc0Verifier.init, (address(0)))
        });

        // Deploy sp1 plonk verifier
        SuccinctVerifier succinctVerifier = new SuccinctVerifier();
        writeJson("succinct_verifier", address(succinctVerifier));
        console2.log("** Deployed SP1 remote verifier: ", address(succinctVerifier));

        sp1Verifier = deployProxy({
            name: "sp1_reth_verifier",
            impl: address(new SP1Verifier(l2ChainId, address(succinctVerifier))),
            // Owner is initially the deployer contract because we need to set the
            // image ids
            data: abi.encodeCall(SP1Verifier.init, (address(0)))
        });
    }

    function deployWrapperContracts(
        address _owner,
        address _taikoInbox,
        address _emptyImpl
    )
        private
        returns (WrapperContracts memory wrapperContracts)
    {
        wrapperContracts.forcedInclusionStore =
            deployProxy({ name: "forced_inclusion_store", impl: _emptyImpl, data: "" });

        wrapperContracts.taikoWrapper =
            deployProxy({ name: "taiko_wrapper", impl: _emptyImpl, data: "" });

        UUPSUpgradeable(wrapperContracts.forcedInclusionStore).upgradeTo(
            address(
                new ForcedInclusionStore(
                    inclusionWindow, inclusionFeeInGwei, _taikoInbox, wrapperContracts.taikoWrapper
                )
            )
        );

        if (usePreconf) {
            wrapperContracts.preconfWhitelist = deployProxy({
                name: "preconf_whitelist",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (_owner, 2))
            });

            wrapperContracts.preconfRouter = deployProxy({
                name: "preconf_router",
                impl: address(
                    new PreconfRouter(
                        wrapperContracts.taikoWrapper,
                        wrapperContracts.preconfWhitelist,
                        fallbackPreconf
                    )
                ),
                data: abi.encodeCall(PreconfRouter.init, (_owner))
            });
        }

        UUPSUpgradeable(wrapperContracts.taikoWrapper).upgradeTo({
            newImplementation: address(
                new TaikoWrapper(
                    _taikoInbox, wrapperContracts.forcedInclusionStore, wrapperContracts.preconfRouter
                )
            )
        });
    }

    function deployForkRouter(
        address _taikoWrapper,
        address _proofVerifier,
        address _signalService,
        address _taikoInbox
    )
        internal
    {
        // Since this is a fresh protocol deployment, we don't have an old fork to use.
        address oldFork = address(0);
        address newFork = deployInbox(_taikoWrapper, _proofVerifier, _signalService);

        UUPSUpgradeable(_taikoInbox).upgradeTo({
            newImplementation: address(new PacayaForkRouter(oldFork, newFork))
        });
    }

    function setupVerifiers(VerifierContracts memory _verifiers) internal {
        // Setup Risc0Verifier
        // ---------------------------------------------------------------
        Risc0Verifier risc0Verifier = Risc0Verifier(_verifiers.risc0RethVerifier);
        risc0Verifier.setImageIdTrusted(risc0BlockProvingImageId, true);
        risc0Verifier.setImageIdTrusted(risc0AggregationImageId, true);
        console2.log("** Risc0Verifier image IDs configured");

        // Setup SP1Verifier
        // ---------------------------------------------------------------
        SP1Verifier sp1Verifier = SP1Verifier(_verifiers.sp1RethVerifier);
        sp1Verifier.setProgramTrusted(sp1BlockProvingProgramVKey, true);
        sp1Verifier.setProgramTrusted(sp1AggregationProgramVKey, true);
        console2.log("** SP1Verifier program verification keys configured");

        // Setup SGX Verifier
        // ---------------------------------------------------------------
        setupSGXVerifier(_verifiers);
    }

    function setupSGXVerifier(VerifierContracts memory _verifiers) internal {
        // Setup Automata DCAP Attestation
        AutomataDcapV3Attestation automataAttestation =
            AutomataDcapV3Attestation(_verifiers.automataProxy);

        // Set MR Enclave if provided
        if (mrEnclave != bytes32(0)) {
            automataAttestation.setMrEnclave(mrEnclave, true);
            console2.log("** MR_ENCLAVE set:", uint256(mrEnclave));
        }

        // Set MR Signer if provided
        if (mrSigner != bytes32(0)) {
            automataAttestation.setMrSigner(mrSigner, true);
            console2.log("** MR_SIGNER set:", uint256(mrSigner));
        }

        // Configure QE Identity if path provided
        string memory qeidPath = vm.envString("QEID_PATH");
        if (bytes(qeidPath).length > 0) {
            // Parse input json
            string memory enclaveIdJson = vm.readFile(string.concat(vm.projectRoot(), qeidPath));
            (bool success, EnclaveIdStruct.EnclaveId memory parsedEnclaveId) =
                AttestationLib.parseEnclaveIdentityJson(enclaveIdJson);
            require(success, "setupSGXVerifier: failed to parse enclave id");

            // Configure QE identity
            automataAttestation.configureQeIdentityJson(parsedEnclaveId);
            console2.log("** QE_IDENTITY_JSON configured");
        }

        // Configure TCB Info if path provided
        string memory tcbInfoPath = vm.envString("TCB_INFO_PATH");
        if (bytes(tcbInfoPath).length > 0) {
            // Parse input json
            string memory tcbInfoJson = vm.readFile(string.concat(vm.projectRoot(), tcbInfoPath));
            (bool success, TCBInfoStruct.TCBInfo memory parsedTcbInfo) =
                AttestationLib.parseTcbInfoJson(tcbInfoJson);
            require(success, "setupSGXVerifier: failed to parse tcb info");

            // Configure TCB info
            string memory fmspc = LibString.lower(parsedTcbInfo.fmspc);
            automataAttestation.configureTcbInfoJson(fmspc, parsedTcbInfo);
            console2.log("** TCB_INFO_JSON configured");
        }

        // Register SGX instance with quote if provided
        bytes memory v3QuoteBytes = vm.envBytes("V3_QUOTE_BYTES");
        if (v3QuoteBytes.length > 0) {
            // Parse bytes input
            V3Struct.ParsedV3QuoteStruct memory v3quote =
                AttestationLib.parseV3QuoteBytes(_verifiers.pemCertChainLibAddr, v3QuoteBytes);

            // Log the instance id to Json
            vm.writeJson(
                vm.serializeUint(
                    "sgx_instance_ids",
                    "sgx_instance_id",
                    SgxVerifier(_verifiers.sgxRethVerifier).nextInstanceId()
                ),
                string.concat(vm.projectRoot(), "/deployments/sgx_instances.json")
            );

            // Format instance address and attempt to register
            SgxVerifier(_verifiers.sgxRethVerifier).registerInstance(v3quote);
            console2.log("** SGX instance registered with quote");
        }

        // Toggle quote validity check
        automataAttestation.toggleLocalReportCheck();
        console2.log("** Quote validity check toggled");
    }

    /// @dev Deploy the inbox contract based on the L2 network
    function deployInbox(
        address _taikoWrapper,
        address _proofVerifier,
        address _signalService
    )
        internal
        returns (address)
    {
        string memory l2Network = vm.envString("L2_NETWORK");

        if (keccak256(abi.encodePacked(l2Network)) == keccak256(abi.encodePacked("devnet"))) {
            return address(
                new SurgeDevnetInbox(
                    SurgeDevnetInbox.ConfigParams({
                        chainId: l2ChainId,
                        cooldownWindow: cooldownWindow,
                        maxVerificationDelay: maxVerificationDelay,
                        livenessBondBase: livenessBondBase
                    }),
                    _taikoWrapper,
                    dao,
                    _proofVerifier,
                    address(0),
                    _signalService
                )
            );
        } else if (keccak256(abi.encodePacked(l2Network)) == keccak256(abi.encodePacked("testnet")))
        {
            return address(
                new SurgeHoodiInbox(
                    SurgeHoodiInbox.ConfigParams({
                        chainId: l2ChainId,
                        cooldownWindow: cooldownWindow,
                        maxVerificationDelay: maxVerificationDelay,
                        livenessBondBase: livenessBondBase
                    }),
                    _taikoWrapper,
                    dao,
                    _proofVerifier,
                    address(0),
                    _signalService
                )
            );
        } else if (keccak256(abi.encodePacked(l2Network)) == keccak256(abi.encodePacked("mainnet")))
        {
            return address(
                new SurgeMainnetInbox(
                    SurgeMainnetInbox.ConfigParams({
                        chainId: l2ChainId,
                        cooldownWindow: cooldownWindow,
                        maxVerificationDelay: maxVerificationDelay,
                        livenessBondBase: livenessBondBase
                    }),
                    _taikoWrapper,
                    dao,
                    _proofVerifier,
                    address(0),
                    _signalService
                )
            );
        } else {
            revert("Invalid L2 network");
        }
    }

    function verifyDeployment(
        SharedContracts memory _sharedContracts,
        RollupContracts memory _rollupContracts,
        WrapperContracts memory _wrapperContracts,
        VerifierContracts memory _verifiers,
        address _sharedResolver,
        address _timelockController
    )
        internal
        view
    {
        // Verify L1 registrations
        // ---------------------------------------------------------------
        verifyL1Registrations(_sharedResolver);

        // Verify L2 registrations
        // ---------------------------------------------------------------
        verifyL2Registrations(_sharedResolver);

        // Build L1 contracts list
        // ---------------------------------------------------------------
        address[] memory l1Contracts = new address[](15);
        l1Contracts[0] = _sharedContracts.signalService;
        l1Contracts[1] = _sharedContracts.bridge;
        l1Contracts[2] = _sharedContracts.erc20Vault;
        l1Contracts[3] = _sharedContracts.erc721Vault;
        l1Contracts[4] = _sharedContracts.erc1155Vault;
        l1Contracts[5] = _rollupContracts.proofVerifier;
        l1Contracts[6] = _rollupContracts.taikoInbox;
        l1Contracts[7] = _wrapperContracts.forcedInclusionStore;
        l1Contracts[8] = _wrapperContracts.taikoWrapper;
        l1Contracts[9] = _wrapperContracts.preconfWhitelist;
        l1Contracts[10] = _wrapperContracts.preconfRouter;
        l1Contracts[11] = _verifiers.automataProxy;
        l1Contracts[12] = _verifiers.risc0RethVerifier;
        l1Contracts[13] = _verifiers.sp1RethVerifier;
        l1Contracts[14] = _verifiers.sgxRethVerifier;

        // Verify ownership
        // ---------------------------------------------------------------
        verifyOwnership(l1Contracts, _timelockController);

        console2.log("** Deployment verified **");
    }

    function verifyL1Registrations(address _sharedResolver) internal view {
        bytes32[] memory sharedNames = new bytes32[](9);
        sharedNames[0] = bytes32("taiko");
        sharedNames[1] = bytes32("signal_service");
        sharedNames[2] = bytes32("bridge");
        sharedNames[3] = bytes32("erc20_vault");
        sharedNames[4] = bytes32("erc721_vault");
        sharedNames[5] = bytes32("erc1155_vault");
        sharedNames[6] = bytes32("bridged_erc20");
        sharedNames[7] = bytes32("bridged_erc721");
        sharedNames[8] = bytes32("bridged_erc1155");

        // Get addresses from shared resolver
        address[] memory sharedAddresses = new address[](sharedNames.length);
        for (uint256 i = 0; i < sharedNames.length; i++) {
            try DefaultResolver(_sharedResolver).resolve(block.chainid, sharedNames[i], true)
            returns (address addr) {
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
                != address(0),
            "verifyL2Registrations: signal_service"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("bridge"), false)
                != address(0),
            "verifyL2Registrations: bridge"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("erc20_vault"), false)
                != address(0),
            "verifyL2Registrations: erc20_vault"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("erc721_vault"), false)
                != address(0),
            "verifyL2Registrations: erc721_vault"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("erc1155_vault"), false)
                != address(0),
            "verifyL2Registrations: erc1155_vault"
        );

        console2.log("** L2 registrations verified **");
    }

    function verifyOwnership(address[] memory _contracts, address _expectedOwner) internal view {
        for (uint256 i; i < _contracts.length; ++i) {
            if (_contracts[i] == address(0)) {
                continue;
            }

            require(
                OwnableUpgradeable(_contracts[i]).owner() == _expectedOwner,
                string.concat("verifyOwnership: ", Strings.toHexString(uint160(_contracts[i]), 20))
            );
        }
    }

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
}
