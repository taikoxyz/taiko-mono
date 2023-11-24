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
            impl: new AddressManager().initDead(),
            data: bytes.concat(AddressManager.init.selector),
            addressManager: address(0),
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "taiko_token",
            impl: new TaikoToken().initDead(),
            data: bytes.concat(
                TaikoToken.init.selector,
                abi.encode(
                    "Taiko Token Katla", //
                    "TTKOk",
                    vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT")
                )
                ),
            addressManager: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "signal_service",
            impl: new SignalService().initDead(),
            data: bytes.concat(SignalService.init.selector),
            addressManager: sharedAddressManager,
            owner: msg.sender // We set msg.sender as the owner and will change it later.
         });

        LibDeployHelper.deployProxy({
            name: "bridge",
            impl: new Bridge().initDead(),
            data: bytes.concat(Bridge.init.selector, abi.encode(sharedAddressManager)),
            addressManager: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        // Deploy Vaults
        LibDeployHelper.deployProxy({
            name: "erc20_vault",
            impl: new ERC20Vault().initDead(),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            addressManager: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "erc721_vault",
            impl: new ERC721Vault().initDead(),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            addressManager: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "erc1155_vault",
            impl: new ERC1155Vault().initDead(),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            addressManager: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        // Deploy Bridged tokens
        LibDeployHelper.register(
            sharedAddressManager, "bridged_erc20", new BridgedERC20().initDead()
        );
        LibDeployHelper.register(
            sharedAddressManager, "bridged_erc721", new BridgedERC721().initDead()
        );
        LibDeployHelper.register(
            sharedAddressManager, "bridged_erc1155", new BridgedERC1155().initDead()
        );
    }

    function deployRollupContracts(address _sharedAddressManager)
        internal
        returns (address rollupAddressManager)
    {
        addressNotNull(_sharedAddressManager, "sharedAddressManager");

        rollupAddressManager = LibDeployHelper.deployProxy({
            name: "address_manager_for_rollup",
            impl: new AddressManager().initDead(),
            data: bytes.concat(AddressManager.init.selector),
            addressManager: address(0),
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "taiko",
            impl: new TaikoL1().initDead(),
            data: bytes.concat(
                TaikoL1.init.selector,
                abi.encode(rollupAddressManager, vm.envBytes32("L2_GENESIS_HASH"))
                ),
            addressManager: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "tier_provider",
            impl: address(new TaikoA6TierProvider()),
            data: "",
            addressManager: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "tier_guardian",
            impl: new GuardianVerifier().initDead(),
            data: bytes.concat(GuardianVerifier.init.selector, abi.encode(rollupAddressManager)),
            addressManager: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "tier_sgx",
            impl: new SgxVerifier().initDead(),
            data: bytes.concat(SgxVerifier.init.selector, abi.encode(rollupAddressManager)),
            addressManager: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        LibDeployHelper.deployProxy({
            name: "tier_sgx_and_pse_zkevm",
            impl: new SgxAndZkVerifier().initDead(),
            data: bytes.concat(SgxAndZkVerifier.init.selector, abi.encode(rollupAddressManager)),
            addressManager: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        address pseZkVerifier = LibDeployHelper.deployProxy({
            name: "tier_pse_zkevm",
            impl: new PseZkVerifier().initDead(),
            data: bytes.concat(PseZkVerifier.init.selector, abi.encode(rollupAddressManager)),
            addressManager: rollupAddressManager,
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
            impl: new GuardianProver().initDead(),
            data: bytes.concat(GuardianProver.init.selector, abi.encode(rollupAddressManager)),
            addressManager: rollupAddressManager,
            owner: msg.sender
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
        // Extra contracts
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
