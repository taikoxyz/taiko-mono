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
abstract contract Deployer is Script {
    struct Ctx {
        address addressManager;
        address owner;
        uint64 chainId;
    }

    Ctx internal _ctx;

    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "invalid priv key");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}

contract DeployOnL1 is Deployer {
    uint256 public constant NUM_GUARDIANS = 5;

    function run() external broadcast {
        address sharedAddressManager = _deploySharedContracts();
        address rollupAddressManager = _deployRollupContracts(sharedAddressManager);

        address signalServiceAddr =
            AddressManager(sharedAddressManager).getAddress(uint64(block.chainid), "signal_service");
        require(signalServiceAddr != address(0), "invalid signal service");
        SignalService signalService = SignalService(signalServiceAddr);

        address taikoL1Addr =
            AddressManager(rollupAddressManager).getAddress(uint64(block.chainid), "taiko");
        require(taikoL1Addr != address(0), "invalid taikoL1Addr");
        TaikoL1 taikoL1 = TaikoL1(payable(taikoL1Addr));

        if (signalService.owner() == msg.sender) {
            signalService.authorize(taikoL1Addr, bytes32(block.chainid));
            signalService.transferOwnership(vm.envAddress("OWNER"));
        } else {
            // TODO
            // print warning for manually authorize the chain.
        }

        // Register bridge and signal singlton
        _ctx = Ctx({
            addressManager: rollupAddressManager,
            chainId: uint64(block.chainid),
            owner: vm.envAddress("OWNER")
        });

        _registerFrom("taiko_token", sharedAddressManager);
        _registerFrom("signal_service", sharedAddressManager);
        _registerFrom("bridge", sharedAddressManager);

        _ctx.addressManager = rollupAddressManager;

        address proposer = vm.envAddress("PROPOSER");
        if (proposer != address(0)) {
            _register("proposer", proposer);
        }

        address proposerOne = vm.envAddress("PROPOSER_ONE");
        if (proposerOne != address(0)) {
            _register("proposer_one", proposerOne);
        }

        uint64 l2ChainId = taikoL1.getConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        _ctx = Ctx({ addressManager: rollupAddressManager, chainId: l2ChainId, owner: address(0) });
        _register("taiko", vm.envAddress("TAIKO_L2_ADDRESS"));
        _register("signal_service", vm.envAddress("L2_SIGNAL_SERVICE"));

        _deployAuxContracts();
    }

    function _deployAuxContracts() private {
        // Extra contracts
        address horseToken = address(new FreeMintERC20("Horse Token", "HORSE"));
        console2.log("HorseToken", horseToken);

        address bullToken = address(new  MayFailFreeMintERC20("Bull Token", "BULL"));
        console2.log("BullToken", bullToken);
    }

    function _deploy(
        bytes32 name,
        address implementation,
        bytes memory data
    )
        private
        returns (address proxy)
    {
        require(_ctx.owner != address(0), "null owner");
        proxy = LibDeploy.deployERC1967Proxy(implementation, _ctx.owner, data);

        console2.log("----------------------------");
        if (_ctx.addressManager != address(0)) {
            AddressManager(_ctx.addressManager).setAddress(_ctx.chainId, name, proxy);
            console2.log(Strings.toString(uint256(name)), "@", _ctx.addressManager);
        } else {
            console2.log(Strings.toString(uint256(name)));
        }

        console2.log("\t proxy : ", proxy);
        console2.log("\t impl  : ", implementation);

        // TODO
        // vm.writeJson(
        //     vm.serializeAddress("deployment", name, proxy),
        //     string.concat(vm.projectRoot(), "/deployments/deploy_l1.json")
        // );
    }

    function _register(bytes32 name, address addr) private {
        require(_ctx.addressManager != address(0), "null manager");
        require(addr != address(0), "null address");
        AddressManager(_ctx.addressManager).setAddress(_ctx.chainId, name, addr);
        console2.log("----------------------------");
        console2.log(Strings.toString(uint256(name)), "@", _ctx.addressManager);
        console2.log("\t addr : ", addr);
    }

    function _registerFrom(bytes32 name, address srcAddressManager) private {
        require(srcAddressManager != address(0), "null src manager");
        _register(name, AddressManager(srcAddressManager).getAddress(_ctx.chainId, name));
    }

    function _deploySharedContracts() internal returns (address sharedAddressManager) {
        address _sharedAddressManager = vm.envAddress("BRIDGE_ADDRESS_MANAGER");
        if (_sharedAddressManager != address(0)) {
            return _sharedAddressManager;
        }

        _ctx = Ctx({
            addressManager: address(0),
            chainId: uint64(block.chainid),
            owner: vm.envAddress("OWNER")
        });

        require(_ctx.owner != address(0), "invalid owner");

        sharedAddressManager = _deploy(
            "address_manager_for_bridge",
            address(new AddressManager()),
            bytes.concat(AddressManager.init.selector)
        );

        _ctx.addressManager = sharedAddressManager;
        _deploy(
            "taiko_token",
            address(new TaikoToken()),
            bytes.concat(
                TaikoToken.init.selector,
                abi.encode(
                    "Taiko Token Katla", "TTKOk", vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT")
                )
            )
        );

        _deploy(
            "bridge",
            address(new Bridge()),
            bytes.concat(Bridge.init.selector, abi.encode(_ctx.addressManager))
        );

        // Deploy Bridged tokens
        _register("bridged_erc20", address(new BridgedERC20()));
        _register("bridged_erc721", address(new BridgedERC721()));
        _register("bridged_erc1155", address(new BridgedERC1155()));

        // Deploy Vaults
        _deploy(
            "erc20_vault",
            address(new ERC20Vault()),
            bytes.concat(BaseVault.init.selector, abi.encode(_ctx.addressManager))
        );
        _deploy(
            "erc721_vault",
            address(new ERC721Vault()),
            bytes.concat(BaseVault.init.selector, abi.encode(_ctx.addressManager))
        );
        _deploy(
            "erc1155_vault",
            address(new ERC1155Vault()),
            bytes.concat(BaseVault.init.selector, abi.encode(_ctx.addressManager))
        );

        _ctx =
            Ctx({ addressManager: address(0), chainId: uint64(block.chainid), owner: address(0) });
        _deploy(
            "signal_service",
            address(new SignalService()),
            bytes.concat(SignalService.init.selector, abi.encode(_ctx.addressManager))
        );
    }

    function _deployRollupContracts(address _sharedAddressManager)
        internal
        returns (address rollupAddressManager)
    {
        require(_sharedAddressManager != address(0), "null bridge address manager");

        _ctx = Ctx({
            addressManager: address(0),
            chainId: uint64(block.chainid),
            owner: vm.envAddress("OWNER")
        });
        require(_ctx.owner != address(0), "invalid owner");

        rollupAddressManager = _deploy(
            "address_manager_for_rollup",
            address(new AddressManager()),
            bytes.concat(AddressManager.init.selector)
        );

        _ctx.addressManager = rollupAddressManager;

        _deploy(
            "taiko",
            address(new TaikoL1()),
            bytes.concat(
                TaikoL1.init.selector,
                abi.encode(_ctx.addressManager, vm.envBytes32("L2_GENESIS_HASH"))
            )
        );

        _deploy("tier_provider", address(new TaikoA6TierProvider()), "");

        _deploy(
            "tier_guardian",
            address(new GuardianVerifier()),
            bytes.concat(GuardianVerifier.init.selector, abi.encode(_ctx.addressManager))
        );

        _deploy(
            "tier_sgx",
            address(new SgxVerifier()),
            bytes.concat(SgxVerifier.init.selector, abi.encode(_ctx.addressManager))
        );

        _deploy(
            "tier_sgx_and_pse_zkevm",
            address(new SgxAndZkVerifier()),
            bytes.concat(SgxAndZkVerifier.init.selector, abi.encode(_ctx.addressManager))
        );

        address pseZkVerifier = _deploy(
            "tier_pse_zkevm",
            address(new PseZkVerifier()),
            bytes.concat(PseZkVerifier.init.selector, abi.encode(_ctx.addressManager))
        );

        address[] memory plonkVerifiers = new address[](1);
        plonkVerifiers[0] = _deployYulContract("contracts/L1/verifiers/PlonkVerifier.yulp");

        for (uint16 i = 0; i < plonkVerifiers.length; ++i) {
            _register(PseZkVerifier(pseZkVerifier).getVerifierName(i), plonkVerifiers[i]);
        }

        // Guardian prover
        _ctx = Ctx({
            addressManager: address(0),
            chainId: uint64(block.chainid),
            owner: address(0) // owner will be msg.sender
         });

        address guardianProver = _deploy(
            "guardian_prover",
            address(new GuardianProver()),
            bytes.concat(GuardianProver.init.selector, abi.encode(_ctx.addressManager))
        );

        address[] memory guardianProvers = vm.envAddress("GUARDIAN_PROVERS", ",");
        require(guardianProvers.length == NUM_GUARDIANS, "invalid guardian provers number");

        address[NUM_GUARDIANS] memory guardians;
        for (uint256 i = 0; i < NUM_GUARDIANS; ++i) {
            guardians[i] = guardianProvers[i];
        }
        GuardianProver(guardianProver).setGuardians(guardians);
        GuardianProver(guardianProver).transferOwnership(vm.envAddress("OWNER"));
    }

    function _deployYulContract(string memory contractPath) private returns (address addr) {
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

        require(addr != address(0), "failed yu deployment");
        console2.log(contractPath, addr);
    }
}
