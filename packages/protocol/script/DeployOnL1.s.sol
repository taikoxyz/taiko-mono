// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../contracts/L1/TaikoL1.sol";
import "../contracts/L1/provers/GuardianProver.sol";
import "../contracts/L1/verifiers/PseZkVerifier.sol";
import "../contracts/L1/verifiers/SgxVerifier.sol";
import "../contracts/L1/verifiers/SgxAndZkVerifier.sol";
import "../contracts/L1/verifiers/GuardianVerifier.sol";
import "../contracts/L1/tiers/TaikoA6TierProvider.sol";
import "../contracts/L1/hooks/AssignmentHook.sol";
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

    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "invalid priv key");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        addressNotNull(vm.envAddress("OWNER"), "OWNER");
        addressNotNull(vm.envAddress("TAIKO_L2_ADDRESS"), "TAIKO_L2_ADDRESS");
        addressNotNull(vm.envAddress("L2_SIGNAL_SERVICE"), "L2_SIGNAL_SERVICE");
        require(vm.envBytes32("L2_GENESIS_HASH") != 0, "L2_GENESIS_HASH");

        address sharedAddressManager = deploySharedContracts();
        address rollupAddressManager = deployRollupContracts(sharedAddressManager);

        address signalServiceAddr =
            AddressManager(sharedAddressManager).getAddress(uint64(block.chainid), "signal_service");
        addressNotNull(signalServiceAddr, "signalServiceAddr");
        SignalService signalService = SignalService(signalServiceAddr);

        address taikoL1Addr =
            AddressManager(rollupAddressManager).getAddress(uint64(block.chainid), "taiko");
        addressNotNull(taikoL1Addr, "taikoL1Addr");
        TaikoL1 taikoL1 = TaikoL1(payable(taikoL1Addr));

        if (signalService.owner() == msg.sender) {
            signalService.authorize(taikoL1Addr, bytes32(block.chainid));
            signalService.transferOwnership(vm.envAddress("OWNER"));
        } else {
            console2.log("------------------------------------------");
            console2.log("Warining - you need to transact manually:");
            console2.log("signalService.authorize(taikoL1Addr, bytes32(block.chainid))");
            console2.log("- signalService : ", signalServiceAddr);
            console2.log("- taikoL1Addr   : ", taikoL1Addr);
            console2.log("- chainId       : ", block.chainid);
        }

        LibDeployHelper.copyRigister(rollupAddressManager, sharedAddressManager, "taiko_token");
        LibDeployHelper.copyRigister(rollupAddressManager, sharedAddressManager, "signal_service");
        LibDeployHelper.copyRigister(rollupAddressManager, sharedAddressManager, "bridge");

        address proposer = vm.envAddress("PROPOSER");
        if (proposer != address(0)) {
            LibDeployHelper.register(rollupAddressManager, "proposer", proposer);
        }

        address proposerOne = vm.envAddress("PROPOSER_ONE");
        if (proposerOne != address(0)) {
            LibDeployHelper.register(rollupAddressManager, "proposer_one", proposerOne);
        }

        uint64 l2ChainId = taikoL1.getConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        LibDeployHelper.register(
            rollupAddressManager, "taiko", vm.envAddress("TAIKO_L2_ADDRESS"), l2ChainId
        );
        LibDeployHelper.register(
            rollupAddressManager, "signal_service", vm.envAddress("L2_SIGNAL_SERVICE"), l2ChainId
        );

        deployAuxContracts();
    }

    function deploySharedContracts() internal returns (address sharedAddressManager) {
        sharedAddressManager = vm.envAddress("SHARED_ADDRESS_MANAGER");
        if (sharedAddressManager != address(0)) {
            return sharedAddressManager;
        }

        sharedAddressManager = LibDeployHelper.deployProxy({
            name: "address_manager_for_bridge",
            impl: address(new AddressManager()),
            data: bytes.concat(AddressManager.init.selector),
            registerTo: address(0),
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "taiko_token",
            impl: address(new TaikoToken()),
            data: bytes.concat(
                TaikoToken.init.selector,
                abi.encode(
                    "Taiko Token Katla", //
                    "TTKOk",
                    vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT")
                )
                ),
            registerTo: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

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
            owner: vm.envAddress("OWNER")
        });

        // Deploy Vaults
        LibDeployHelper.deployProxy({
            name: "erc20_vault",
            impl: address(new ERC20Vault()),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            registerTo: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "erc721_vault",
            impl: address(new ERC721Vault()),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            registerTo: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "erc1155_vault",
            impl: address(new ERC1155Vault()),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            registerTo: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        // Deploy Bridged tokens
        LibDeployHelper.register(sharedAddressManager, "bridged_erc20", address(new BridgedERC20()));
        LibDeployHelper.register(
            sharedAddressManager, "bridged_erc721", address(new BridgedERC721())
        );
        LibDeployHelper.register(
            sharedAddressManager, "bridged_erc1155", address(new BridgedERC1155())
        );
    }

    function deployRollupContracts(address _sharedAddressManager)
        internal
        returns (address rollupAddressManager)
    {
        addressNotNull(_sharedAddressManager, "sharedAddressManager");

        rollupAddressManager = LibDeployHelper.deployProxy({
            name: "address_manager_for_rollup",
            impl: address(new AddressManager()),
            data: bytes.concat(AddressManager.init.selector),
            registerTo: address(0),
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "taiko",
            impl: address(new TaikoL1()),
            data: bytes.concat(
                TaikoL1.init.selector,
                abi.encode(rollupAddressManager, vm.envBytes32("L2_GENESIS_HASH"))
                ),
            registerTo: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "tier_pse_zkevm",
            impl: address(new AssignmentHook()),
            data: bytes.concat(AssignmentHook.init.selector, abi.encode(rollupAddressManager)),
            registerTo: address(0),
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "tier_provider",
            impl: address(new TaikoA6TierProvider()),
            data: bytes.concat(TaikoA6TierProvider.init.selector),
            registerTo: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "tier_guardian",
            impl: address(new GuardianVerifier()),
            data: bytes.concat(GuardianVerifier.init.selector, abi.encode(rollupAddressManager)),
            registerTo: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "tier_sgx",
            impl: address(new SgxVerifier()),
            data: bytes.concat(SgxVerifier.init.selector, abi.encode(rollupAddressManager)),
            registerTo: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "tier_sgx_and_pse_zkevm",
            impl: address(new SgxAndZkVerifier()),
            data: bytes.concat(SgxAndZkVerifier.init.selector, abi.encode(rollupAddressManager)),
            registerTo: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        address pseZkVerifier = LibDeployHelper.deployProxy({
            name: "tier_pse_zkevm",
            impl: address(new PseZkVerifier()),
            data: bytes.concat(PseZkVerifier.init.selector, abi.encode(rollupAddressManager)),
            registerTo: rollupAddressManager,
            owner: vm.envAddress("OWNER")
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
            owner: address(0)
        });

        address[] memory guardianProvers = vm.envAddress("GUARDIAN_PROVERS", ",");
        require(guardianProvers.length == NUM_GUARDIANS, "NUM_GUARDIANS");

        address[NUM_GUARDIANS] memory guardians;
        for (uint256 i = 0; i < NUM_GUARDIANS; ++i) {
            guardians[i] = guardianProvers[i];
        }
        GuardianProver(guardianProver).setGuardians(guardians);
        GuardianProver(guardianProver).transferOwnership(vm.envAddress("OWNER"));
    }

    function deployAuxContracts() private {
        address horseToken = address(new FreeMintERC20("Horse Token", "HORSE"));
        console2.log("HorseToken", horseToken);

        address bullToken = address(new  MayFailFreeMintERC20("Bull Token", "BULL"));
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

        addressNotNull(addr, "failed yu deployment");
        console2.log(contractPath, addr);
    }

    function addressNotNull(address addr, string memory err) private pure {
        require(addr != address(0), err);
    }
}
