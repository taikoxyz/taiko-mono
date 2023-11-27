// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../contracts/L1/TaikoL1.sol";
import "../contracts/L1/hooks/AssignmentHook.sol";
import "../contracts/L1/provers/GuardianProver.sol";
import "../contracts/L1/verifiers/PseZkVerifier.sol";
import "../contracts/L1/verifiers/SgxVerifier.sol";
import "../contracts/L1/verifiers/SgxAndZkVerifier.sol";
import "../contracts/L1/verifiers/GuardianVerifier.sol";
import "../contracts/L1/tiers/TaikoA6TierProvider.sol";
import "../contracts/L1/hooks/AssignmentHook.sol";
import "../contracts/L1/gov/TaikoGovernor.sol";
import "../contracts/bridge/Bridge.sol";
import "../contracts/tokenvault/ERC20Vault.sol";
import "../contracts/tokenvault/ERC1155Vault.sol";
import "../contracts/tokenvault/ERC721Vault.sol";
import "../contracts/signal/SignalService.sol";
import "../contracts/test/erc20/FreeMintERC20.sol";
import "../contracts/test/erc20/MayFailFreeMintERC20.sol";
import "../contracts/libs/LibDeployHelper.sol";

/// @title DeployOnL1
/// @notice This script deploys the core Taiko protocol smart contract on L1,
/// initializing the rollup.
contract DeployOnL1 is Script {
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
        (address sharedAddressManager, address timelock) = deploySharedContracts();
        console2.log("sharedAddressManager: ", sharedAddressManager);
        console2.log("timelock: ", timelock);
        // ---------------------------------------------------------------
        // Deploy rollup contracts
        address rollupAddressManager = deployRollupContracts(sharedAddressManager, timelock);

        // ---------------------------------------------------------------
        // Signal service need to authorize the new rollup
        address signalServiceAddr =
            AddressManager(sharedAddressManager).getAddress(uint64(block.chainid), "signal_service");
        addressNotNull(signalServiceAddr, "signalServiceAddr");
        SignalService signalService = SignalService(signalServiceAddr);

        address taikoL1Addr =
            AddressManager(rollupAddressManager).getAddress(uint64(block.chainid), "taiko");
        addressNotNull(taikoL1Addr, "taikoL1Addr");
        TaikoL1 taikoL1 = TaikoL1(payable(taikoL1Addr));

        uint64 l2ChainId = taikoL1.getConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        if (signalService.owner() == msg.sender) {
            signalService.authorize(taikoL1Addr, bytes32(block.chainid));
            signalService.authorize(vm.envAddress("TAIKO_L2_ADDRESS"), bytes32(uint256(l2ChainId)));
            signalService.transferOwnership(timelock);
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
        LibDeployHelper.copyRegister(rollupAddressManager, sharedAddressManager, "taiko_token");
        LibDeployHelper.copyRegister(rollupAddressManager, sharedAddressManager, "signal_service");
        LibDeployHelper.copyRegister(rollupAddressManager, sharedAddressManager, "bridge");

        address proposer = vm.envAddress("PROPOSER");
        if (proposer != address(0)) {
            LibDeployHelper.register(rollupAddressManager, "proposer", proposer);
        }

        address proposerOne = vm.envAddress("PROPOSER_ONE");
        if (proposerOne != address(0)) {
            LibDeployHelper.register(rollupAddressManager, "proposer_one", proposerOne);
        }

        // ---------------------------------------------------------------
        // Register L2 addresses
        LibDeployHelper.register(
            rollupAddressManager, "taiko", vm.envAddress("TAIKO_L2_ADDRESS"), l2ChainId
        );
        LibDeployHelper.register(
            rollupAddressManager, "signal_service", vm.envAddress("L2_SIGNAL_SERVICE"), l2ChainId
        );

        // ---------------------------------------------------------------
        // Deploy other contracts
        deployAuxContracts();

        if (AddressManager(sharedAddressManager).owner() == msg.sender) {
            AddressManager(sharedAddressManager).transferOwnership(timelock);
        }
        if (AddressManager(rollupAddressManager).owner() == msg.sender) {
            AddressManager(rollupAddressManager).transferOwnership(timelock);
        }
    }

    function deploySharedContracts()
        internal
        returns (address sharedAddressManager, address timelock)
    {
        sharedAddressManager = vm.envAddress("SHARED_ADDRESS_MANAGER");
        if (sharedAddressManager != address(0)) {
            return (sharedAddressManager, vm.envAddress("TIMELOCK_CONTROLLER"));
        }

        // Deploy the timelock
        TimelockController _timelock = new TimelockController({
                minDelay: 7 days,
                proposers: new address[](0),
                executors: new address[](0),
                admin: msg.sender});

        timelock = address(_timelock);
        console2.log("timelock: ", timelock);

        sharedAddressManager = LibDeployHelper.deployProxy({
            name: "address_manager_for_bridge",
            impl: address(new AddressManager()),
            data: bytes.concat(AddressManager.init.selector),
            registerTo: address(0),
            owner: msg.sender // set to sender, transfer ownership to timelock after
         });

        address taikoToken = LibDeployHelper.deployProxy({
            name: "taiko_token",
            impl: address(new TaikoToken()),
            data: bytes.concat(
                TaikoToken.init.selector,
                abi.encode(
                    vm.envString("TAIKO_TOKEN_NAME"),
                    vm.envString("TAIKO_TOKEN_SYMBOL"),
                    vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT")
                )
                ),
            registerTo: sharedAddressManager,
            owner: timelock
        });

        address governor = address(new TaikoGovernor(IVotes(taikoToken), _timelock));
        console2.log("governor: ", governor);

        // Setup time lock roles
        _timelock.grantRole(_timelock.PROPOSER_ROLE(), governor);
        _timelock.grantRole(_timelock.EXECUTOR_ROLE(), governor);
        _timelock.grantRole(_timelock.CANCELLER_ROLE(), address(governor));

        _timelock.grantRole(_timelock.TIMELOCK_ADMIN_ROLE(), securityCouncil);
        _timelock.renounceRole(_timelock.TIMELOCK_ADMIN_ROLE(), msg.sender);

        // Deploy Bridging contracts
        LibDeployHelper.deployProxy({
            name: "signal_service",
            impl: address(new SignalService()),
            data: bytes.concat(SignalService.init.selector),
            registerTo: sharedAddressManager,
            owner: msg.sender // We set msg.sender as the owner and will change it later.
         });

        LibDeployHelper.deployProxy({
            name: "bridge",
            impl: address(new Bridge()),
            data: bytes.concat(Bridge.init.selector, abi.encode(sharedAddressManager)),
            registerTo: sharedAddressManager,
            owner: timelock
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
        LibDeployHelper.deployProxy({
            name: "erc20_vault",
            impl: address(new ERC20Vault()),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            registerTo: sharedAddressManager,
            owner: timelock
        });

        LibDeployHelper.deployProxy({
            name: "erc721_vault",
            impl: address(new ERC721Vault()),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            registerTo: sharedAddressManager,
            owner: timelock
        });

        LibDeployHelper.deployProxy({
            name: "erc1155_vault",
            impl: address(new ERC1155Vault()),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            registerTo: sharedAddressManager,
            owner: timelock
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
        LibDeployHelper.register(sharedAddressManager, "bridged_erc20", address(new BridgedERC20()));
        LibDeployHelper.register(
            sharedAddressManager, "bridged_erc721", address(new BridgedERC721())
        );
        LibDeployHelper.register(
            sharedAddressManager, "bridged_erc1155", address(new BridgedERC1155())
        );
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

        rollupAddressManager = LibDeployHelper.deployProxy({
            name: "address_manager_for_rollup",
            impl: address(new AddressManager()),
            data: bytes.concat(AddressManager.init.selector),
            registerTo: address(0),
            owner: msg.sender // set to msg.sender, change to timelock after
         });

        LibDeployHelper.deployProxy({
            name: "taiko",
            impl: address(new TaikoL1()),
            data: bytes.concat(
                TaikoL1.init.selector,
                abi.encode(rollupAddressManager, vm.envBytes32("L2_GENESIS_HASH"))
                ),
            registerTo: rollupAddressManager,
            owner: timelock
        });

        LibDeployHelper.deployProxy({
            name: "assignment_hook",
            impl: address(new AssignmentHook()),
            data: bytes.concat(AssignmentHook.init.selector, abi.encode(rollupAddressManager)),
            registerTo: address(0),
            owner: timelock
        });

        LibDeployHelper.deployProxy({
            name: "tier_provider",
            impl: address(new TaikoA6TierProvider()),
            data: bytes.concat(TaikoA6TierProvider.init.selector),
            registerTo: rollupAddressManager,
            owner: timelock
        });

        LibDeployHelper.deployProxy({
            name: "tier_guardian",
            impl: address(new GuardianVerifier()),
            data: bytes.concat(GuardianVerifier.init.selector, abi.encode(rollupAddressManager)),
            registerTo: rollupAddressManager,
            owner: timelock
        });

        LibDeployHelper.deployProxy({
            name: "tier_sgx",
            impl: address(new SgxVerifier()),
            data: bytes.concat(SgxVerifier.init.selector, abi.encode(rollupAddressManager)),
            registerTo: rollupAddressManager,
            owner: timelock
        });

        LibDeployHelper.deployProxy({
            name: "tier_sgx_and_pse_zkevm",
            impl: address(new SgxAndZkVerifier()),
            data: bytes.concat(SgxAndZkVerifier.init.selector, abi.encode(rollupAddressManager)),
            registerTo: rollupAddressManager,
            owner: timelock
        });

        address pseZkVerifier = LibDeployHelper.deployProxy({
            name: "tier_pse_zkevm",
            impl: address(new PseZkVerifier()),
            data: bytes.concat(PseZkVerifier.init.selector, abi.encode(rollupAddressManager)),
            registerTo: rollupAddressManager,
            owner: timelock
        });

        address[] memory plonkVerifiers = new address[](1);
        plonkVerifiers[0] = deployYulContract("contracts/L1/verifiers/PlonkVerifier.yulp");

        for (uint16 i = 0; i < plonkVerifiers.length; ++i) {
            LibDeployHelper.register(
                rollupAddressManager,
                PseZkVerifier(pseZkVerifier).getVerifierName(i),
                plonkVerifiers[i]
            );
        }

        address guardianProver = LibDeployHelper.deployProxy({
            name: "guardian_prover",
            impl: address(new GuardianProver()),
            data: bytes.concat(GuardianProver.init.selector, abi.encode(rollupAddressManager)),
            registerTo: rollupAddressManager,
            owner: msg.sender
        });

        address[] memory guardianProvers = vm.envAddress("GUARDIAN_PROVERS", ",");
        require(guardianProvers.length == NUM_GUARDIANS, "NUM_GUARDIANS");

        address[NUM_GUARDIANS] memory guardians;
        for (uint256 i = 0; i < NUM_GUARDIANS; ++i) {
            guardians[i] = guardianProvers[i];
        }
        GuardianProver(guardianProver).setGuardians(guardians);
        GuardianProver(guardianProver).transferOwnership(timelock);
    }

    function deployAuxContracts() private {
        address horseToken = address(new FreeMintERC20("Horse Token", "HORSE"));
        console2.log("HorseToken", horseToken);

        address bullToken = address(new MayFailFreeMintERC20("Bull Token", "BULL"));
        console2.log("BullToken", bullToken);
    }

    function deployYulContract(string memory contractPath) private returns (address addr) {
        string[] memory cmds = new string[](3);
        cmds[0] = "bash";
        cmds[1] = "-c";
        cmds[2] = string.concat(
            vm.projectRoot(),
            "/bin/solc --yul --bin ",
            string.concat(vm.projectRoot(), "/", contractPath),
            " | grep -A1 Binary | tail -1"
        );

        bytes memory bytecode = vm.ffi(cmds);
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        addressNotNull(addr, "failed yul deployment");
        console2.log(contractPath, addr);
    }

    function addressNotNull(address addr, string memory err) private pure {
        require(addr != address(0), err);
    }
}
