// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";

import "../contracts/common/LibStrings.sol";
import "../contracts/L1/TaikoToken.sol";
import "../contracts/L1/TaikoL1.sol";
import "../contracts/L1/provers/GuardianProver.sol";
import "../contracts/L1/tiers/DevnetTierProvider.sol";
import "../contracts/L1/tiers/TierProviderV1.sol";
import "../contracts/L1/tiers/TierProviderV2.sol";
import "../contracts/L1/hooks/AssignmentHook.sol";
import "../contracts/L1/gov/TaikoTimelockController.sol";
import "../contracts/L1/gov/TaikoGovernor.sol";
import "../contracts/bridge/Bridge.sol";
import "../contracts/tokenvault/ERC20Vault.sol";
import "../contracts/tokenvault/ERC1155Vault.sol";
import "../contracts/tokenvault/ERC721Vault.sol";
import "../contracts/signal/SignalService.sol";
import "../contracts/automata-attestation/AutomataDcapV3Attestation.sol";
import "../contracts/automata-attestation/utils/SigVerifyLib.sol";
import "../contracts/automata-attestation/lib/PEMCertChainLib.sol";
import "../contracts/verifiers/SgxVerifier.sol";
import "../test/common/erc20/FreeMintERC20.sol";
import "../test/common/erc20/MayFailFreeMintERC20.sol";
import "../test/DeployCapability.sol";

// Actually this one is deployed already on mainnet, but we are now deploying our own (non via-ir)
// version. For mainnet, it is easier to go with one of:
// - https://github.com/daimo-eth/p256-verifier
// - https://github.com/rdubois-crypto/FreshCryptoLib
import { P256Verifier } from "p256-verifier/src/P256Verifier.sol";

/// @title DeployOnL1
/// @notice This script deploys the core Taiko protocol smart contract on L1,
/// initializing the rollup.
contract DeployOnL1 is DeployCapability {
    uint256 public constant NUM_GUARDIANS = 5;

    address public constant MAINNET_SECURITY_COUNCIL = 0x7C50d60743D3FCe5a39FdbF687AFbAe5acFF49Fd;

    address securityCouncil =
        block.chainid == 1 ? MAINNET_SECURITY_COUNCIL : vm.envAddress("SECURITY_COUNCIL");

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
        require(vm.envBytes32("L2_GENESIS_HASH") != 0, "L2_GENESIS_HASH");

        // ---------------------------------------------------------------
        // Deploy shared contracts
        (address sharedAddressManager, address timelock, address governor) = deploySharedContracts();
        console2.log("sharedAddressManager: ", sharedAddressManager);
        console2.log("timelock: ", timelock);
        // ---------------------------------------------------------------
        // Deploy rollup contracts
        address rollupAddressManager = deployRollupContracts(sharedAddressManager, timelock);

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

        TaikoTimelockController _timelock = TaikoTimelockController(payable(timelock));

        if (signalService.owner() == msg.sender) {
            // Setup time lock roles
            // Only the governor can make proposals after holders voting.
            _timelock.grantRole(_timelock.PROPOSER_ROLE(), governor);
            _timelock.grantRole(_timelock.PROPOSER_ROLE(), msg.sender);

            // Granting address(0) the executor role to allow open execution.
            _timelock.grantRole(_timelock.EXECUTOR_ROLE(), address(0));
            _timelock.grantRole(_timelock.EXECUTOR_ROLE(), msg.sender);

            _timelock.grantRole(_timelock.TIMELOCK_ADMIN_ROLE(), securityCouncil);
            _timelock.grantRole(_timelock.PROPOSER_ROLE(), securityCouncil);
            _timelock.grantRole(_timelock.EXECUTOR_ROLE(), securityCouncil);

            signalService.transferOwnership(timelock);
            acceptOwnership(signalServiceAddr, TimelockControllerUpgradeable(payable(timelock)));
        } else {
            console2.log("------------------------------------------");
            console2.log("Warning - you need to transact manually:");
            console2.log("signalService.authorize(taikoL1Addr, bytes32(block.chainid))");
            console2.log("- signalService : ", signalServiceAddr);
            console2.log("- taikoL1Addr   : ", taikoL1Addr);
            console2.log("- chainId       : ", block.chainid);
        }

        // ---------------------------------------------------------------
        // Register shared contracts in the new rollup
        copyRegister(rollupAddressManager, sharedAddressManager, "taiko_token");
        copyRegister(rollupAddressManager, sharedAddressManager, "signal_service");
        copyRegister(rollupAddressManager, sharedAddressManager, "bridge");

        address proposer = vm.envAddress("PROPOSER");
        if (proposer != address(0)) {
            register(rollupAddressManager, "proposer", proposer);
        }

        address proposerOne = vm.envAddress("PROPOSER_ONE");
        if (proposerOne != address(0)) {
            register(rollupAddressManager, "proposer_one", proposerOne);
        }

        // ---------------------------------------------------------------
        // Register L2 addresses
        register(rollupAddressManager, "taiko", vm.envAddress("TAIKO_L2_ADDRESS"), l2ChainId);
        register(
            rollupAddressManager, "signal_service", vm.envAddress("L2_SIGNAL_SERVICE"), l2ChainId
        );

        // ---------------------------------------------------------------
        // Deploy other contracts
        deployAuxContracts();

        if (AddressManager(sharedAddressManager).owner() == msg.sender) {
            AddressManager(sharedAddressManager).transferOwnership(timelock);
            acceptOwnership(sharedAddressManager, TimelockControllerUpgradeable(payable(timelock)));
            console2.log("** sharedAddressManager ownership transferred to timelock:", timelock);
        }

        AddressManager(rollupAddressManager).transferOwnership(timelock);
        acceptOwnership(rollupAddressManager, TimelockControllerUpgradeable(payable(timelock)));
        console2.log("** rollupAddressManager ownership transferred to timelock:", timelock);

        _timelock.revokeRole(_timelock.TIMELOCK_ADMIN_ROLE(), address(this));
        _timelock.revokeRole(_timelock.PROPOSER_ROLE(), msg.sender);
        _timelock.revokeRole(_timelock.EXECUTOR_ROLE(), msg.sender);
        _timelock.transferOwnership(securityCouncil);
        _timelock.renounceRole(_timelock.TIMELOCK_ADMIN_ROLE(), msg.sender);
    }

    function deploySharedContracts()
        internal
        returns (address sharedAddressManager, address timelock, address governor)
    {
        // Deploy the timelock
        timelock = deployProxy({
            name: "timelock_controller",
            impl: address(new TaikoTimelockController()),
            data: abi.encodeCall(TaikoTimelockController.init, (address(0), 7 days))
        });

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
                    TaikoToken.init,
                    (
                        timelock,
                        vm.envString("TAIKO_TOKEN_NAME"),
                        vm.envString("TAIKO_TOKEN_SYMBOL"),
                        vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT")
                    )
                    ),
                registerTo: sharedAddressManager
            });
        }

        governor = deployProxy({
            name: "taiko_governor",
            impl: address(new TaikoGovernor()),
            data: abi.encodeCall(
                TaikoGovernor.init,
                (
                    timelock,
                    IVotesUpgradeable(taikoToken),
                    TimelockControllerUpgradeable(payable(timelock))
                )
                )
        });

        // Deploy Bridging contracts
        deployProxy({
            name: "signal_service",
            impl: address(new SignalService()),
            data: abi.encodeCall(SignalService.init, (address(0), sharedAddressManager)),
            registerTo: sharedAddressManager
        });

        deployProxy({
            name: "bridge",
            impl: address(new Bridge()),
            data: abi.encodeCall(Bridge.init, (timelock, sharedAddressManager)),
            registerTo: sharedAddressManager
        });

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
            name: "erc20_vault",
            impl: address(new ERC20Vault()),
            data: abi.encodeCall(ERC20Vault.init, (timelock, sharedAddressManager)),
            registerTo: sharedAddressManager
        });

        deployProxy({
            name: "erc721_vault",
            impl: address(new ERC721Vault()),
            data: abi.encodeCall(ERC721Vault.init, (timelock, sharedAddressManager)),
            registerTo: sharedAddressManager
        });

        deployProxy({
            name: "erc1155_vault",
            impl: address(new ERC1155Vault()),
            data: abi.encodeCall(ERC1155Vault.init, (timelock, sharedAddressManager)),
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
        address timelock
    )
        internal
        returns (address rollupAddressManager)
    {
        addressNotNull(_sharedAddressManager, "sharedAddressManager");
        addressNotNull(timelock, "timelock");

        rollupAddressManager = deployProxy({
            name: "rollup_address_manager",
            impl: address(new AddressManager()),
            data: abi.encodeCall(AddressManager.init, (address(0)))
        });

        deployProxy({
            name: "taiko",
            impl: address(new TaikoL1()),
            data: abi.encodeCall(
                TaikoL1.init, (timelock, rollupAddressManager, vm.envBytes32("L2_GENESIS_HASH"))
                ),
            registerTo: rollupAddressManager
        });

        deployProxy({
            name: "assignment_hook",
            impl: address(new AssignmentHook()),
            data: abi.encodeCall(AssignmentHook.init, (timelock, rollupAddressManager))
        });

        deployProxy({
            name: "tier_provider",
            impl: deployTierProvider(vm.envString("TIER_PROVIDER")),
            data: abi.encodeCall(TierProviderV1.init, (timelock)),
            registerTo: rollupAddressManager
        });

        deployProxy({
            name: "tier_sgx",
            impl: address(new SgxVerifier()),
            data: abi.encodeCall(SgxVerifier.init, (timelock, rollupAddressManager)),
            registerTo: rollupAddressManager
        });

        address guardianProverImpl = address(new GuardianProver());

        address guardianProverMinority = deployProxy({
            name: "guardian_prover_minority",
            impl: guardianProverImpl,
            data: abi.encodeCall(GuardianProver.init, (address(0), rollupAddressManager)),
            registerTo: rollupAddressManager
        });

        address guardianProver = deployProxy({
            name: "guardian_prover",
            impl: guardianProverImpl,
            data: abi.encodeCall(GuardianProver.init, (address(0), rollupAddressManager)),
            registerTo: rollupAddressManager
        });

        register(rollupAddressManager, "tier_guardian_minority", guardianProverMinority);
        register(rollupAddressManager, "tier_guardian", guardianProver);

        address[] memory guardians = vm.envAddress("GUARDIAN_PROVERS", ",");

        GuardianProver(guardianProverMinority).setGuardians(guardians, 1);
        GuardianProver(guardianProverMinority).transferOwnership(timelock);

        GuardianProver(guardianProver).setGuardians(guardians, uint8(vm.envUint("MIN_GUARDIANS")));
        GuardianProver(guardianProver).transferOwnership(timelock);

        // No need to proxy these, because they are 3rd party. If we want to modify, we simply
        // change the registerAddress("automata_dcap_attestation", address(attestation));
        P256Verifier p256Verifier = new P256Verifier();
        SigVerifyLib sigVerifyLib = new SigVerifyLib(address(p256Verifier));
        PEMCertChainLib pemCertChainLib = new PEMCertChainLib();
        AutomataDcapV3Attestation automateDcapV3Attestation =
            new AutomataDcapV3Attestation(address(sigVerifyLib), address(pemCertChainLib));

        // Log addresses for the user to register sgx instance
        console2.log("SigVerifyLib", address(sigVerifyLib));
        console2.log("PemCertChainLib", address(pemCertChainLib));
        register(
            rollupAddressManager, "automata_dcap_attestation", address(automateDcapV3Attestation)
        );
    }

    function deployTierProvider(string memory tierProviderName) private returns (address) {
        if (keccak256(abi.encode(tierProviderName)) == keccak256(abi.encode("devnet"))) {
            return address(new DevnetTierProvider());
        } else if (keccak256(abi.encode(tierProviderName)) == keccak256(abi.encode("testnet"))) {
            return address(new TierProviderV1());
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

    function acceptOwnership(address proxy, TimelockControllerUpgradeable timelock) internal {
        bytes32 salt = bytes32(block.timestamp);
        bytes memory payload = abi.encodeCall(Ownable2StepUpgradeable(proxy).acceptOwnership, ());

        timelock.schedule(proxy, 0, payload, bytes32(0), salt, 0);
        timelock.execute(proxy, 0, payload, bytes32(0), salt);
    }
}
