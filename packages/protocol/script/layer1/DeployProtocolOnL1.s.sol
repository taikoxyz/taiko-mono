// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import { SP1Verifier as SuccinctVerifier } from "@sp1-contracts/src/v3.0.0-rc3/SP1VerifierPlonk.sol";

// Actually this one is deployed already on mainnet, but we are now deploying our own (non via-ir)
// version. For mainnet, it is easier to go with one of:
// - https://github.com/daimo-eth/p256-verifier
// - https://github.com/rdubois-crypto/FreshCryptoLib
import "@p256-verifier/contracts/P256Verifier.sol";

import "src/shared/common/LibStrings.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/tokenvault/BridgedERC20.sol";
import "src/shared/tokenvault/BridgedERC721.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";
import "src/layer1/devnet/DevnetTaikoL1.sol";
import "src/layer1/devnet/DevnetTierProvider.sol";
import "src/layer1/mainnet/rollup/MainnetGuardianProver.sol";
import "src/layer1/mainnet/rollup/MainnetTaikoL1.sol";
import "src/layer1/mainnet/rollup/verifiers/MainnetSgxVerifier.sol";
import "src/layer1/mainnet/multirollup/MainnetBridge.sol";
import "src/layer1/mainnet/multirollup/MainnetERC1155Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetERC20Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetERC721Vault.sol";
import "src/layer1/mainnet/multirollup/MainnetSignalService.sol";
import "src/layer1/provers/GuardianProver.sol";
import "src/layer1/provers/ProverSet.sol";
import "src/layer1/tiers/TierProviderV2.sol";
import "src/layer1/token/TaikoToken.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "test/layer1/based/TestTierProvider.sol";
import "test/shared/token/FreeMintERC20.sol";
import "test/shared/token/MayFailFreeMintERC20.sol";
import "test/shared/DeployCapability.sol";

/// @title DeployProtocolOnL1
/// @notice This script deploys the core Taiko protocol smart contract on L1,
/// initializing the rollup.
contract DeployProtocolOnL1 is DeployCapability {
    uint256 public NUM_MIN_MAJORITY_GUARDIANS = vm.envUint("NUM_MIN_MAJORITY_GUARDIANS");
    uint256 public NUM_MIN_MINORITY_GUARDIANS = vm.envUint("NUM_MIN_MINORITY_GUARDIANS");

    address public constant MAINNET_CONTRACT_OWNER = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F; // admin.taiko.eth

    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "invalid priv key");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        addressNotNull(vm.envAddress("TAIKO_L2_ADDRESS"), "TAIKO_L2_ADDRESS");
        addressNotNull(vm.envAddress("L2_SIGNAL_SERVICE"), "L2_SIGNAL_SERVICE");
        addressNotNull(vm.envAddress("CONTRACT_OWNER"), "CONTRACT_OWNER");

        require(vm.envBytes32("L2_GENESIS_HASH") != 0, "L2_GENESIS_HASH");
        address contractOwner = vm.envAddress("CONTRACT_OWNER");

        // ---------------------------------------------------------------
        // Deploy shared contracts
        (address sharedAddressManager) = deploySharedContracts(contractOwner);
        console2.log("sharedAddressManager: ", sharedAddressManager);
        // ---------------------------------------------------------------
        // Deploy rollup contracts
        address rollupAddressManager = deployRollupContracts(sharedAddressManager, contractOwner);

        // ---------------------------------------------------------------
        // Signal service need to authorize the new rollup
        address signalServiceAddr = AddressManager(sharedAddressManager).getAddress(
            uint64(block.chainid), LibStrings.B_SIGNAL_SERVICE
        );
        addressNotNull(signalServiceAddr, "signalServiceAddr");
        SignalService signalService = SignalService(signalServiceAddr);

        address taikoL1Addr = AddressManager(rollupAddressManager).getAddress(
            uint64(block.chainid), LibStrings.B_TAIKO
        );
        addressNotNull(taikoL1Addr, "taikoL1Addr");
        TaikoL1 taikoL1 = TaikoL1(payable(taikoL1Addr));

        if (vm.envAddress("SHARED_ADDRESS_MANAGER") == address(0)) {
            SignalService(signalServiceAddr).authorize(taikoL1Addr, true);
        }

        uint64 l2ChainId = taikoL1.getConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        console2.log("------------------------------------------");
        console2.log("msg.sender: ", msg.sender);
        console2.log("address(this): ", address(this));
        console2.log("signalService.owner(): ", signalService.owner());
        console2.log("------------------------------------------");

        if (signalService.owner() == msg.sender) {
            signalService.transferOwnership(contractOwner);
        } else {
            console2.log("------------------------------------------");
            console2.log("Warning - you need to transact manually:");
            console2.log("signalService.authorize(taikoL1Addr, bytes32(block.chainid))");
            console2.log("- signalService : ", signalServiceAddr);
            console2.log("- taikoL1Addr   : ", taikoL1Addr);
            console2.log("- chainId       : ", block.chainid);
        }

        // ---------------------------------------------------------------
        // Register L2 addresses
        register(rollupAddressManager, "taiko", vm.envAddress("TAIKO_L2_ADDRESS"), l2ChainId);
        register(
            rollupAddressManager, "signal_service", vm.envAddress("L2_SIGNAL_SERVICE"), l2ChainId
        );

        // ---------------------------------------------------------------
        // Deploy other contracts
        if (block.chainid != 1) {
            deployAuxContracts();
        }

        if (AddressManager(sharedAddressManager).owner() == msg.sender) {
            AddressManager(sharedAddressManager).transferOwnership(contractOwner);
            console2.log("** sharedAddressManager ownership transferred to:", contractOwner);
        }

        AddressManager(rollupAddressManager).transferOwnership(contractOwner);
        console2.log("** rollupAddressManager ownership transferred to:", contractOwner);
    }

    function deploySharedContracts(address owner) internal returns (address sharedAddressManager) {
        addressNotNull(owner, "owner");

        sharedAddressManager = vm.envAddress("SHARED_ADDRESS_MANAGER");
        if (sharedAddressManager == address(0)) {
            sharedAddressManager = deployProxy({
                name: "shared_address_manager",
                impl: address(new AddressManager()),
                data: abi.encodeCall(AddressManager.init, (address(0)))
            });
        }

        address taikoToken = vm.envAddress("TAIKO_TOKEN");
        if (taikoToken == address(0)) {
            taikoToken = deployProxy({
                name: "taiko_token",
                impl: address(new TaikoToken()),
                data: abi.encodeCall(
                    TaikoToken.init, (owner, vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT"))
                ),
                registerTo: sharedAddressManager
            });
        }

        // Deploy Bridging contracts
        deployProxy({
            name: "mainnet_signal_service",
            impl: address(new MainnetSignalService()),
            data: abi.encodeCall(SignalService.init, (address(0), sharedAddressManager))
        });
        deployProxy({
            name: "signal_service",
            impl: address(new SignalService()),
            data: abi.encodeCall(SignalService.init, (address(0), sharedAddressManager)),
            registerTo: sharedAddressManager
        });

        deployProxy({
            name: "mainnet_bridge",
            impl: address(new MainnetBridge()),
            data: abi.encodeCall(Bridge.init, (address(0), sharedAddressManager))
        });
        address brdige = deployProxy({
            name: "bridge",
            impl: address(new Bridge()),
            data: abi.encodeCall(Bridge.init, (address(0), sharedAddressManager)),
            registerTo: sharedAddressManager
        });

        if (vm.envBool("PAUSE_BRIDGE")) {
            Bridge(payable(brdige)).pause();
        }

        Bridge(payable(brdige)).transferOwnership(owner);

        console2.log("------------------------------------------");
        console2.log(
            "Warning - you need to register *all* counterparty bridges to enable multi-hop bridging:"
        );
        console2.log(
            "sharedAddressManager.setAddress(remoteChainId, \"bridge\", address(remoteBridge))"
        );
        console2.log("- sharedAddressManager : ", sharedAddressManager);

        // Deploy Vaults
        deployProxy({
            name: "mainnet_erc20_vault",
            impl: address(new MainnetERC20Vault()),
            data: abi.encodeCall(ERC20Vault.init, (owner, sharedAddressManager))
        });
        deployProxy({
            name: "erc20_vault",
            impl: address(new ERC20Vault()),
            data: abi.encodeCall(ERC20Vault.init, (owner, sharedAddressManager)),
            registerTo: sharedAddressManager
        });

        deployProxy({
            name: "mainnet_erc721_vault",
            impl: address(new MainnetERC721Vault()),
            data: abi.encodeCall(ERC721Vault.init, (owner, sharedAddressManager))
        });
        deployProxy({
            name: "erc721_vault",
            impl: address(new ERC721Vault()),
            data: abi.encodeCall(ERC721Vault.init, (owner, sharedAddressManager)),
            registerTo: sharedAddressManager
        });

        deployProxy({
            name: "mainnet_erc1155_vault",
            impl: address(new MainnetERC1155Vault()),
            data: abi.encodeCall(ERC1155Vault.init, (owner, sharedAddressManager))
        });
        deployProxy({
            name: "erc1155_vault",
            impl: address(new ERC1155Vault()),
            data: abi.encodeCall(ERC1155Vault.init, (owner, sharedAddressManager)),
            registerTo: sharedAddressManager
        });

        console2.log("------------------------------------------");
        console2.log(
            "Warning - you need to register *all* counterparty vaults to enable multi-hop bridging:"
        );
        console2.log(
            "sharedAddressManager.setAddress(remoteChainId, \"erc20_vault\", address(remoteERC20Vault))"
        );
        console2.log(
            "sharedAddressManager.setAddress(remoteChainId, \"erc721_vault\", address(remoteERC721Vault))"
        );
        console2.log(
            "sharedAddressManager.setAddress(remoteChainId, \"erc1155_vault\", address(remoteERC1155Vault))"
        );
        console2.log("- sharedAddressManager : ", sharedAddressManager);

        // Deploy Bridged token implementations
        register(sharedAddressManager, "bridged_erc20", address(new BridgedERC20()));
        register(sharedAddressManager, "bridged_erc721", address(new BridgedERC721()));
        register(sharedAddressManager, "bridged_erc1155", address(new BridgedERC1155()));
    }

    function deployRollupContracts(
        address _sharedAddressManager,
        address owner
    )
        internal
        returns (address rollupAddressManager)
    {
        addressNotNull(_sharedAddressManager, "sharedAddressManager");
        addressNotNull(owner, "owner");

        rollupAddressManager = deployProxy({
            name: "rollup_address_manager",
            impl: address(new AddressManager()),
            data: abi.encodeCall(AddressManager.init, (address(0)))
        });

        // ---------------------------------------------------------------
        // Register shared contracts in the new rollup
        copyRegister(rollupAddressManager, _sharedAddressManager, "taiko_token");
        copyRegister(rollupAddressManager, _sharedAddressManager, "signal_service");
        copyRegister(rollupAddressManager, _sharedAddressManager, "bridge");

        deployProxy({
            name: "mainnet_taiko",
            impl: address(new MainnetTaikoL1()),
            data: abi.encodeCall(
                TaikoL1.init,
                (
                    owner,
                    rollupAddressManager,
                    vm.envBytes32("L2_GENESIS_HASH"),
                    vm.envBool("PAUSE_TAIKO_L1")
                )
            )
        });

        TaikoL1 taikoL1;
        if (keccak256(abi.encode(vm.envString("TIER_PROVIDER"))) == keccak256(abi.encode("devnet")))
        {
            taikoL1 = TaikoL1(address(new DevnetTaikoL1()));
        } else {
            taikoL1 = TaikoL1(address(new TaikoL1()));
        }

        deployProxy({
            name: "taiko",
            impl: address(taikoL1),
            data: abi.encodeCall(
                TaikoL1.init,
                (
                    owner,
                    rollupAddressManager,
                    vm.envBytes32("L2_GENESIS_HASH"),
                    vm.envBool("PAUSE_TAIKO_L1")
                )
            ),
            registerTo: rollupAddressManager
        });

        deployProxy({
            name: "mainnet_tier_sgx",
            impl: address(new MainnetSgxVerifier()),
            data: abi.encodeCall(SgxVerifier.init, (owner, rollupAddressManager))
        });

        deployProxy({
            name: "tier_sgx",
            impl: address(new SgxVerifier()),
            data: abi.encodeCall(SgxVerifier.init, (owner, rollupAddressManager)),
            registerTo: rollupAddressManager
        });

        deployProxy({
            name: "mainnet_guardian_prover_minority",
            impl: address(new MainnetGuardianProver()),
            data: abi.encodeCall(GuardianProver.init, (address(0), rollupAddressManager))
        });

        address guardianProverImpl = address(new GuardianProver());

        address guardianProverMinority = deployProxy({
            name: "guardian_prover_minority",
            impl: guardianProverImpl,
            data: abi.encodeCall(GuardianProver.init, (address(0), rollupAddressManager))
        });

        GuardianProver(guardianProverMinority).enableTaikoTokenAllowance(true);

        address guardianProver = deployProxy({
            name: "guardian_prover",
            impl: guardianProverImpl,
            data: abi.encodeCall(GuardianProver.init, (address(0), rollupAddressManager))
        });

        register(rollupAddressManager, "tier_guardian_minority", guardianProverMinority);
        register(rollupAddressManager, "tier_guardian", guardianProver);
        register(
            rollupAddressManager,
            "tier_router",
            address(deployTierProvider(vm.envString("TIER_PROVIDER")))
        );

        address[] memory guardians = vm.envAddress("GUARDIAN_PROVERS", ",");

        GuardianProver(guardianProverMinority).setGuardians(
            guardians, uint8(NUM_MIN_MINORITY_GUARDIANS), true
        );
        GuardianProver(guardianProverMinority).transferOwnership(owner);

        GuardianProver(guardianProver).setGuardians(
            guardians, uint8(NUM_MIN_MAJORITY_GUARDIANS), true
        );
        GuardianProver(guardianProver).transferOwnership(owner);

        // No need to proxy these, because they are 3rd party. If we want to modify, we simply
        // change the registerAddress("automata_dcap_attestation", address(attestation));
        P256Verifier p256Verifier = new P256Verifier();
        SigVerifyLib sigVerifyLib = new SigVerifyLib(address(p256Verifier));
        PEMCertChainLib pemCertChainLib = new PEMCertChainLib();
        address automateDcapV3AttestationImpl = address(new AutomataDcapV3Attestation());

        address automataProxy = deployProxy({
            name: "automata_dcap_attestation",
            impl: automateDcapV3AttestationImpl,
            data: abi.encodeCall(
                AutomataDcapV3Attestation.init, (owner, address(sigVerifyLib), address(pemCertChainLib))
            ),
            registerTo: rollupAddressManager
        });

        // Log addresses for the user to register sgx instance
        console2.log("SigVerifyLib", address(sigVerifyLib));
        console2.log("PemCertChainLib", address(pemCertChainLib));
        console2.log("AutomataDcapVaAttestation", automataProxy);

        deployProxy({
            name: "prover_set",
            impl: address(new ProverSet()),
            data: abi.encodeCall(
                ProverSet.init, (owner, vm.envAddress("PROVER_SET_ADMIN"), rollupAddressManager)
            )
        });

        deployZKVerifiers(owner, rollupAddressManager);
    }

    // deploy both sp1 & risc0 verifiers.
    // using function to avoid stack too deep error
    function deployZKVerifiers(address owner, address rollupAddressManager) private {
        // Deploy r0 groth16 verifier
        RiscZeroGroth16Verifier verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);
        register(rollupAddressManager, "risc0_groth16_verifier", address(verifier));

        deployProxy({
            name: "tier_zkvm_risc0",
            impl: address(new Risc0Verifier()),
            data: abi.encodeCall(Risc0Verifier.init, (owner, rollupAddressManager)),
            registerTo: rollupAddressManager
        });

        // Deploy sp1 plonk verifier
        SuccinctVerifier succinctVerifier = new SuccinctVerifier();
        register(rollupAddressManager, "sp1_remote_verifier", address(succinctVerifier));

        deployProxy({
            name: "tier_zkvm_sp1",
            impl: address(new SP1Verifier()),
            data: abi.encodeCall(SP1Verifier.init, (owner, rollupAddressManager)),
            registerTo: rollupAddressManager
        });
    }

    function deployTierProvider(string memory tierProviderName) private returns (address) {
        if (keccak256(abi.encode(tierProviderName)) == keccak256(abi.encode("devnet"))) {
            return address(new DevnetTierProvider());
        } else if (keccak256(abi.encode(tierProviderName)) == keccak256(abi.encode("testnet"))) {
            return address(new TestTierProvider());
        } else if (keccak256(abi.encode(tierProviderName)) == keccak256(abi.encode("mainnet"))) {
            return address(new TierProviderV2());
        } else {
            revert("invalid tier provider");
        }
    }

    function deployAuxContracts() private {
        address horseToken = address(new FreeMintERC20("Horse Token", "HORSE"));
        console2.log("HorseToken", horseToken);

        address bullToken = address(new MayFailFreeMintERC20("Bull Token", "BULL"));
        console2.log("BullToken", bullToken);
    }

    function addressNotNull(address addr, string memory err) private pure {
        require(addr != address(0), err);
    }
}
