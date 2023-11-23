// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

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
import "../contracts/libs/LibDeploy.sol";
import "../contracts/test/erc20/FreeMintERC20.sol";
import "../contracts/test/erc20/MayFailFreeMintERC20.sol";

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
        address sharedAddressManager = deploySharedContracts();
        address rollupAddressManager = deployRollupContracts(sharedAddressManager);

        address signalServiceAddr =
            AddressManager(sharedAddressManager).getAddress(chainid(), "signal_service");
        addressNotNull(signalServiceAddr, "signalServiceAddr");
        SignalService signalService = SignalService(signalServiceAddr);

        address taikoL1Addr = AddressManager(rollupAddressManager).getAddress(chainid(), "taiko");
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

        copyRigister(rollupAddressManager, sharedAddressManager, "taiko_token");
        copyRigister(rollupAddressManager, sharedAddressManager, "signal_service");
        copyRigister(rollupAddressManager, sharedAddressManager, "bridge");

        address proposer = vm.envAddress("PROPOSER");
        if (proposer != address(0)) {
            register(rollupAddressManager, "proposer", proposer);
        }

        address proposerOne = vm.envAddress("PROPOSER_ONE");
        if (proposerOne != address(0)) {
            register(rollupAddressManager, "proposer_one", proposerOne);
        }

        uint64 l2ChainId = taikoL1.getConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        register(rollupAddressManager, "taiko", vm.envAddress("TAIKO_L2_ADDRESS"), l2ChainId);
        register(
            rollupAddressManager, "signal_service", vm.envAddress("L2_SIGNAL_SERVICE"), l2ChainId
        );

        deployAuxContracts();
    }

    function deploySharedContracts() internal returns (address sharedAddressManager) {
        sharedAddressManager = vm.envAddress("SHARED_ADDRESS_MANAGER");
        if (sharedAddressManager != address(0)) {
            return sharedAddressManager;
        }

        sharedAddressManager = deployProxy({
            name: "address_manager_for_bridge",
            impl: address(new AddressManager()),
            data: bytes.concat(AddressManager.init.selector),
            addressManager: address(0),
            owner: vm.envAddress("OWNER")
        });

        deployProxy({
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
            addressManager: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        deployProxy({
            name: "signal_service",
            impl: address(new SignalService()),
            data: bytes.concat(SignalService.init.selector, abi.encode(sharedAddressManager)),
            addressManager: sharedAddressManager,
            owner: msg.sender // We set msg.sender as the owner and will change it later.
         });

        deployProxy({
            name: "bridge",
            impl: address(new Bridge()),
            data: bytes.concat(Bridge.init.selector, abi.encode(sharedAddressManager)),
            addressManager: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        // Deploy Vaults
        deployProxy({
            name: "erc20_vault",
            impl: address(new ERC20Vault()),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            addressManager: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        deployProxy({
            name: "erc721_vault",
            impl: address(new ERC721Vault()),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            addressManager: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        deployProxy({
            name: "erc1155_vault",
            impl: address(new ERC1155Vault()),
            data: bytes.concat(BaseVault.init.selector, abi.encode(sharedAddressManager)),
            addressManager: sharedAddressManager,
            owner: vm.envAddress("OWNER")
        });

        // Deploy Bridged tokens
        register(sharedAddressManager, "bridged_erc20", address(new BridgedERC20()));
        register(sharedAddressManager, "bridged_erc721", address(new BridgedERC721()));
        register(sharedAddressManager, "bridged_erc1155", address(new BridgedERC1155()));
    }

    function deployRollupContracts(address _sharedAddressManager)
        internal
        returns (address rollupAddressManager)
    {
        addressNotNull(_sharedAddressManager, "sharedAddressManager");

        rollupAddressManager = deployProxy({
            name: "address_manager_for_rollup",
            impl: address(new AddressManager()),
            data: bytes.concat(AddressManager.init.selector),
            addressManager: address(0),
            owner: vm.envAddress("OWNER")
        });

        deployProxy({
            name: "taiko",
            impl: address(new TaikoL1()),
            data: bytes.concat(
                TaikoL1.init.selector,
                abi.encode(rollupAddressManager, vm.envBytes32("L2_GENESIS_HASH"))
                ),
            addressManager: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        deployProxy({
            name: "tier_provider",
            impl: address(new TaikoA6TierProvider()),
            data: "",
            addressManager: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        deployProxy({
            name: "tier_guardian",
            impl: address(new GuardianVerifier()),
            data: bytes.concat(GuardianVerifier.init.selector, abi.encode(rollupAddressManager)),
            addressManager: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        deployProxy({
            name: "tier_sgx",
            impl: address(new SgxVerifier()),
            data: bytes.concat(SgxVerifier.init.selector, abi.encode(rollupAddressManager)),
            addressManager: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        deployProxy({
            name: "tier_sgx_and_pse_zkevm",
            impl: address(new SgxAndZkVerifier()),
            data: bytes.concat(SgxAndZkVerifier.init.selector, abi.encode(rollupAddressManager)),
            addressManager: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        address pseZkVerifier = deployProxy({
            name: "tier_pse_zkevm",
            impl: address(new PseZkVerifier()),
            data: bytes.concat(PseZkVerifier.init.selector, abi.encode(rollupAddressManager)),
            addressManager: rollupAddressManager,
            owner: vm.envAddress("OWNER")
        });

        address[] memory plonkVerifiers = new address[](1);
        plonkVerifiers[0] = deployYulContract("contracts/L1/verifiers/PlonkVerifier.yulp");

        for (uint16 i = 0; i < plonkVerifiers.length; ++i) {
            register(
                rollupAddressManager,
                PseZkVerifier(pseZkVerifier).getVerifierName(i),
                plonkVerifiers[i]
            );
        }

        address guardianProver = deployProxy({
            name: "guardian_prover",
            impl: address(new GuardianProver()),
            data: bytes.concat(GuardianProver.init.selector, abi.encode(rollupAddressManager)),
            addressManager: rollupAddressManager,
            owner: msg.sender
        });

        address[] memory guardianProvers = vm.envAddress("GUARDIAN_PROVERS", ",");
        assert(guardianProvers.length == NUM_GUARDIANS);

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

    function deployProxy(
        bytes32 name,
        address impl,
        bytes memory data,
        address addressManager,
        address owner
    )
        private
        returns (address proxy)
    {
        proxy = LibDeploy.deployERC1967Proxy(impl, owner, data);

        if (addressManager != address(0)) {
            AddressManager(addressManager).setAddress(chainid(), name, proxy);
        }
        console2.log("> ", Strings.toString(uint256(name)), "@", addressManager);
        console2.log("\t proxy : ", proxy);
        console2.log("\t impl  : ", impl);
        console2.log("\t owner : ", OwnableUpgradeable(proxy).owner());

        // TODO
        // vm.writeJson(
        //     vm.serializeAddress("deployment", name, proxy),
        //     string.concat(vm.projectRoot(), "/deployments/deploy_l1.json")
        // );
    }

    function register(address addressManager, bytes32 name, address addr) private {
        register(addressManager, name, addr, chainid());
    }

    function register(address addressManager, bytes32 name, address addr, uint64 chainId) private {
        addressNotNull(addressManager, "addressManager");
        addressNotNull(addr, "addr");
        AddressManager(addressManager).setAddress(chainId, name, addr);
        console2.log("> ", Strings.toString(uint256(name)), "@", addressManager);
        console2.log("\t addr : ", addr);
    }

    function copyRigister(
        address toAddressManager,
        address fromAddressManager,
        bytes32 name
    )
        private
    {
        require(toAddressManager != address(0));
        require(fromAddressManager != address(0));
        register({
            addressManager: toAddressManager,
            name: name,
            addr: AddressManager(fromAddressManager).getAddress(chainid(), name),
            chainId: chainid()
        });
    }

    function chainid() private view returns (uint64) {
        return uint64(block.chainid);
    }

    function addressNotNull(address addr, string memory err) private pure {
        require(addr != address(0), err);
    }
}
