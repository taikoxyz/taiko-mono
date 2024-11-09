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

import "src/shared/libs/LibStrings.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/tokenvault/BridgedERC20.sol";
import "src/shared/tokenvault/BridgedERC721.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/utils/SigVerifyLib.sol";
import "src/layer1/devnet/DevnetTaikoL1.sol";
import "src/layer1/devnet/DevnetTierRouter.sol";
import "src/layer1/mainnet/rollup/verifiers/MainnetSgxVerifier.sol";
import "src/layer1/provers/GuardianProver.sol";
import "src/layer1/provers/ProverSet.sol";
import "src/layer1/token/TaikoToken.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "test/layer1/based/TestTierRouter.sol";
import "test/shared/token/FreeMintERC20.sol";
import "test/shared/token/MayFailFreeMintERC20.sol";
import "script/BaseScript.sol";

/// @title DeployProtocolOnL1
/// @notice This script deploys the core Taiko protocol smart contract on L1,
/// initializing the rollup.
contract DeployProtocolOnL1 is BaseScript {
    uint256 public NUM_MIN_MAJORITY_GUARDIANS = vm.envUint("NUM_MIN_MAJORITY_GUARDIANS");
    uint256 public NUM_MIN_MINORITY_GUARDIANS = vm.envUint("NUM_MIN_MINORITY_GUARDIANS");
    address public taikoL2 = vm.envAddress("TAIKO_L2_ADDRESS");
    address public tSignalService = vm.envAddress("L2_SIGNAL_SERVICE");
    address public sharedResolverAddress = vm.envAddress("SHARED_RESOLVER");
    address public taikoToken = vm.envAddress("TAIKO_TOKEN");
    address public taikoTokenPremintRecipient = vm.envOr("TAIKO_TOKEN_PREMINT_RECIPIENT", msg.sender    );

    address public constant contractOwner = vm.envOr("OWNER", msg.sender);

    bytes32 public l2GenesisHash = vm.envBytes32("L2_GENESIS_HASH");

    function run() external broadcast {
        addressNotNull(taikoL2, "TAIKO_L2_ADDRESS");
        addressNotNull(tSignalService, "L2_SIGNAL_SERVICE");
        addressNotNull(contractOwner, "CONTRACT_OWNER");

        require(l2GenesisHash != 0, "L2_GENESIS_HASH");

        // ---------------------------------------------------------------
        // Deploy shared contracts
        address sharedResolver = deploySharedContracts();
        console2.log("sharedResolver: ", sharedResolver);
        // ---------------------------------------------------------------
        // Deploy rollup contracts
        DefaultResolver taikoResolver = deployTaikoContracts(sharedResolver, contractOwner);

        // ---------------------------------------------------------------
        // Signal service need to authorize the new rollup
        SignalService signalService = SignalService(sharedResolver.resolve(
            block.chainid, LibStrings.B_SIGNAL_SERVICE, false
        ));
        addressNotNull(address(signalService), "signalService");

        TaikoL1 taikoL1 = TaikoL1(taikoResolver.resolve(
            block.chainid, LibStrings.B_TAIKO, false
        ));
        addressNotNull(address(taikoL1), "taikoL1");

        signalService.authorize(address(taikoL1), true);
      
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
            console2.log("- signalService : ", address(signalService));
            console2.log("- taikoL1       : ", address(taikoL1));
            console2.log("- chainId       : ", block.chainid);
        }

        // ---------------------------------------------------------------
        // Register L2 addresses
        taikoResolver.setAddress(l2ChainId, "taiko", taikoL2);
        taikoResolver.setAddress(l2ChainId, "signal_service", tSignalService);
      

        // ---------------------------------------------------------------
        // Deploy other contracts
        if (block.chainid != 1) {
            deployAuxContracts();
        }

        if (sharedResolver.owner() == msg.sender) {
            sharedResolver.transferOwnership(contractOwner);
            console2.log("** sharedResolver ownership transferred to:", contractOwner);
        }

        taikoResolver.transferOwnership(contractOwner);
        console2.log("** taikoResolver ownership transferred to:", contractOwner);
    }

    function deploySharedContracts() internal returns (DefaultResolver sharedResolver) {

        sharedResolver = DefaultResolver(sharedResolverAddress);
        if (address(sharedResolver) == address(0)) {
            sharedResolver = DefaultResolver(deploy({
                name: "shared_resolver",
                impl: address(new DefaultResolver()),
                data: abi.encodeCall(DefaultResolver.init, (address(0)))
            }));
        }

        if (taikoToken == address(0)) {
            taikoToken = deploy({
                name: "taiko_token",
                impl: address(new TaikoToken()),
                data: abi.encodeCall(
                    TaikoToken.init, (contractOwner, taikoTokenPremintRecipient)
                )
            });
        }
        sharedResolver.setAddress(block.chainid, "taiko_token", taikoToken);
        sharedResolver.setAddress(block.chainid, "bond_token", taikoToken);

  
        deploy({
            name: "signal_service",
            impl: address(new SignalService()),
            data: abi.encodeCall(SignalService.init, (address(0), sharedResolver)),
            _resolver: sharedResolver
        });

  
        Bridge brdige = Bridge(deploy({
            name: "bridge",
            impl: address(new Bridge()),
            data: abi.encodeCall(Bridge.init, (contractOwner, sharedResolver)),
            registerTo: sharedResolver
        }));


        console2.log("------------------------------------------");
        console2.log(
            "Warning - you need to register *all* counterparty bridges to enable multi-hop bridging:"
        );
        console2.log(
            "sharedResolver.setAddress(remoteChainId, \"bridge\", address(remoteBridge))"
        );
        console2.log("- sharedResolver : ", sharedResolver);

        // Deploy Vaults
      
        deploy({
            name: "erc20_vault",
            impl: address(new ERC20Vault()),
            data: abi.encodeCall(ERC20Vault.init, (owner, sharedResolver)),
            registerTo: sharedResolver
        });

       
        deploy({
            name: "erc721_vault",
            impl: address(new ERC721Vault()),
            data: abi.encodeCall(ERC721Vault.init, (owner, sharedResolver)),
            registerTo: sharedResolver
        });

      
        deploy({
            name: "erc1155_vault",
            impl: address(new ERC1155Vault()),
            data: abi.encodeCall(ERC1155Vault.init, (owner, sharedResolver)),
            registerTo: sharedResolver
        });

        console2.log("------------------------------------------");
        console2.log(
            "Warning - you need to register *all* counterparty vaults to enable multi-hop bridging:"
        );
        console2.log(
            "sharedResolver.setAddress(remoteChainId, \"erc20_vault\", address(remoteERC20Vault))"
        );
        console2.log(
            "sharedResolver.setAddress(remoteChainId, \"erc721_vault\", address(remoteERC721Vault))"
        );
        console2.log(
            "sharedResolver.setAddress(remoteChainId, \"erc1155_vault\", address(remoteERC1155Vault))"
        );
        console2.log("- sharedResolver : ", sharedResolver);

        // Deploy Bridged token implementations
        register(sharedResolver, "bridged_erc20", address(new BridgedERC20()));
        register(sharedResolver, "bridged_erc721", address(new BridgedERC721()));
        register(sharedResolver, "bridged_erc1155", address(new BridgedERC1155()));
    }

    function deployTaikoContracts(
        address _sharedResolver,
        address owner
    )
        internal
        returns (address taikoResolver)
    {
        addressNotNull(_sharedResolver, "sharedResolver");
        addressNotNull(owner, "owner");

        taikoResolver = deploy({
            name: "rollup_address_manager",
            impl: address(new AddressManager()),
            data: abi.encodeCall(AddressManager.init, (address(0)))
        });

        // ---------------------------------------------------------------
        // Register shared contracts in the new rollup
        copyRegister(taikoResolver, _sharedResolver, "taiko_token");
        copyRegister(taikoResolver, _sharedResolver, "bond_token");
        copyRegister(taikoResolver, _sharedResolver, "signal_service");
        copyRegister(taikoResolver, _sharedResolver, "bridge");

        deploy({
            name: "mainnet_taiko",
            impl: address(new MainnetTaikoL1()),
            data: abi.encodeCall(
                TaikoL1.init,
                (
                    owner,
                    taikoResolver,
                    vm.envBytes32("L2_GENESIS_HASH"),
                    vm.envBool("PAUSE_TAIKO_L1")
                )
            )
        });

        TaikoL1 taikoL1;
        if (keccak256(abi.encode(vm.envString("TIER_ROUTER"))) == keccak256(abi.encode("devnet"))) {
            taikoL1 = TaikoL1(address(new DevnetTaikoL1()));
        } else {
            taikoL1 = TaikoL1(address(new TaikoL1()));
        }

        deploy({
            name: "taiko",
            impl: address(taikoL1),
            data: abi.encodeCall(
                TaikoL1.init,
                (
                    owner,
                    taikoResolver,
                    vm.envBytes32("L2_GENESIS_HASH"),
                    vm.envBool("PAUSE_TAIKO_L1")
                )
            ),
            registerTo: taikoResolver
        });

        deploy({
            name: "mainnet_tier_sgx",
            impl: address(new MainnetSgxVerifier()),
            data: abi.encodeCall(SgxVerifier.init, (owner, taikoResolver))
        });

        deploy({
            name: "tier_sgx",
            impl: address(new SgxVerifier()),
            data: abi.encodeCall(SgxVerifier.init, (owner, taikoResolver)),
            registerTo: taikoResolver
        });

        deploy({
            name: "mainnet_guardian_prover_minority",
            impl: address(new MainnetGuardianProver()),
            data: abi.encodeCall(GuardianProver.init, (address(0), taikoResolver))
        });

        address guardianProverImpl = address(new GuardianProver());

        address guardianProverMinority = deploy({
            name: "guardian_prover_minority",
            impl: guardianProverImpl,
            data: abi.encodeCall(GuardianProver.init, (address(0), taikoResolver))
        });

        GuardianProver(guardianProverMinority).enableBondAllowance(true);

        address guardianProver = deploy({
            name: "guardian_prover",
            impl: guardianProverImpl,
            data: abi.encodeCall(GuardianProver.init, (address(0), taikoResolver))
        });

        register(taikoResolver, "tier_guardian_minority", guardianProverMinority);
        register(taikoResolver, "tier_guardian", guardianProver);
        register(
            taikoResolver,
            "tier_router",
            address(deployTierRouter(vm.envString("TIER_ROUTER")))
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

        address automataProxy = deploy({
            name: "automata_dcap_attestation",
            impl: automateDcapV3AttestationImpl,
            data: abi.encodeCall(
                AutomataDcapV3Attestation.init, (owner, address(sigVerifyLib), address(pemCertChainLib))
            ),
            registerTo: taikoResolver
        });

        // Log addresses for the user to register sgx instance
        console2.log("SigVerifyLib", address(sigVerifyLib));
        console2.log("PemCertChainLib", address(pemCertChainLib));
        console2.log("AutomataDcapVaAttestation", automataProxy);

        deploy({
            name: "prover_set",
            impl: address(new ProverSet()),
            data: abi.encodeCall(
                ProverSet.init, (owner, vm.envAddress("PROVER_SET_ADMIN"), taikoResolver)
            )
        });

        deployZKVerifiers(owner, taikoResolver);
    }

    // deploy both sp1 & risc0 verifiers.
    // using function to avoid stack too deep error
    function deployZKVerifiers(address owner, address taikoResolver) private {
        // Deploy r0 groth16 verifier
        RiscZeroGroth16Verifier verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);
        register(taikoResolver, "risc0_groth16_verifier", address(verifier));

        deploy({
            name: "tier_zkvm_risc0",
            impl: address(new Risc0Verifier()),
            data: abi.encodeCall(Risc0Verifier.init, (owner, taikoResolver)),
            registerTo: taikoResolver
        });

        // Deploy sp1 plonk verifier
        SuccinctVerifier succinctVerifier = new SuccinctVerifier();
        register(taikoResolver, "sp1_remote_verifier", address(succinctVerifier));

        deploy({
            name: "tier_zkvm_sp1",
            impl: address(new SP1Verifier()),
            data: abi.encodeCall(SP1Verifier.init, (owner, taikoResolver)),
            registerTo: taikoResolver
        });
    }

    function deployTierRouter(string memory tierRouterName) private returns (address) {
        if (keccak256(abi.encode(tierRouterName)) == keccak256(abi.encode("devnet"))) {
            return address(new DevnetTierRouter());
        } else if (keccak256(abi.encode(tierRouterName)) == keccak256(abi.encode("testnet"))) {
            return address(new TestTierRouter());
        } else if (keccak256(abi.encode(tierRouterName)) == keccak256(abi.encode("mainnet"))) {
            address daoFallbackProposer = 0xD3f681bD6B49887A48cC9C9953720903967E9DC0;
            return address(new MainnetTierRouter(daoFallbackProposer));
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

    function addressNotNull(address addr, string memory name) private pure {
        require(addr != address(0), string.concat(name, " is address(0)"));
    }
}
