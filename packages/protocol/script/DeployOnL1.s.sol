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
// import "../contracts/test/erc20/MayFailFreeMintERC20.sol";

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

    error FAILED_TO_DEPLOY_PLONK_VERIFIER(string contractPath);

    function run() external broadcast {
        address bridgeAddressManager = _deployBridgeSuite();
        address rollupAddressManager = _deployTaikoL1Suite(bridgeAddressManager);

        // Authorize the new TaikoL1 contract for shared signal service.
        // TODO
        // SignalService(signalService).authorize(taikoL1Proxy,
        // bytes32(block.chainid));

        _ctx.addressManager = rollupAddressManager;

        address proposer = vm.envAddress("PROPOSER");
        if (proposer != address(0)) {
            _register("proposer", proposer);
        }

        address proposerOne = vm.envAddress("PROPOSER_ONE");
        if (proposerOne != address(0)) {
            _register("proposer_one", proposerOne);
        }

        TaikoL1 taikoL1 = TaikoL1(
            payable(AddressManager(rollupAddressManager).getAddress(uint64(block.chainid), "taiko"))
        );

        uint64 l2ChainId = taikoL1.getConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        _ctx.chainId = l2ChainId;
        _register("taiko", vm.envAddress("TAIKO_L2_ADDRESS"));
        _register("signal_service", vm.envAddress("L2_SIGNAL_SERVICE"));

        address horseToken = address(new FreeMintERC20("Horse Token", "HORSE"));
        console2.log("HorseToken", horseToken);
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
        // console2.log(strings.concat(name, ": ", proxy, " =>", implementation));
    }

    function _registerFrom(bytes32 name, address srcAddressManager) private {
        require(srcAddressManager != address(0), "null src manager");
        _register(name, AddressManager(srcAddressManager).getAddress(_ctx.chainId, name));
    }

    function _deployBridgeSuite() internal returns (address bridgeAddressManager) {
        address _bridgeAddressManager = vm.envAddress("BRIDGE_ADDRESS_MANAGER");
        if (_bridgeAddressManager != address(0)) {
            return _bridgeAddressManager;
        }

        _ctx.addressManager = address(0);
        _ctx.chainId = uint64(block.chainid);
        _ctx.owner = vm.envAddress("OWNER");
        require(_ctx.owner != address(0), "invalid owner");

        bridgeAddressManager = _deploy(
            "address_manager_for_bridge",
            address(new AddressManager()),
            bytes.concat(AddressManager.init.selector)
        );

        _ctx.addressManager = bridgeAddressManager;

        _deploy(
            "signal_service",
            address(new SignalService()),
            bytes.concat(SignalService.init.selector, abi.encode(_ctx.addressManager))
        );

        _deploy(
            "bridge",
            address(new Bridge()),
            bytes.concat(Bridge.init.selector, abi.encode(_ctx.addressManager))
        );

        _register("bridged_erc20", address(new BridgedERC20()));
        _deploy(
            "erc20_vault",
            address(new ERC20Vault()),
            bytes.concat(BaseVault.init.selector, abi.encode(_ctx.addressManager))
        );

        _register("bridged_erc721", address(new BridgedERC721()));
        _deploy(
            "erc721_vault",
            address(new ERC721Vault()),
            bytes.concat(BaseVault.init.selector, abi.encode(_ctx.addressManager))
        );

        _register("bridged_erc1155", address(new BridgedERC1155()));
        _deploy(
            "erc1155_vault",
            address(new ERC1155Vault()),
            bytes.concat(BaseVault.init.selector, abi.encode(_ctx.addressManager))
        );
    }

    function _deployTaikoL1Suite(address _bridgeAddressManager)
        internal
        returns (address rollupAddressManager)
    {
        _ctx.addressManager = address(0);
        _ctx.chainId = uint64(block.chainid);
        _ctx.owner = vm.envAddress("OWNER");
        require(_ctx.owner != address(0), "invalid owner");

        rollupAddressManager = _deploy(
            "address_manager_for_rollup",
            address(new AddressManager()),
            bytes.concat(AddressManager.init.selector)
        );

        _ctx.addressManager = rollupAddressManager;

        _registerFrom("bridge", _bridgeAddressManager);
        _registerFrom("signal_service", _bridgeAddressManager);

        _deploy(
            "taiko_token",
            address(new TaikoToken()),
            bytes.concat(
                TaikoToken.init.selector,
                abi.encode(
                    _ctx.addressManager,
                    "Taiko Token Katla",
                    "TTKOk",
                    vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT")
                )
            )
        );

        _deploy(
            "taiko",
            address(new TaikoL1()),
            bytes.concat(
                TaikoL1.init.selector,
                abi.encode(_ctx.addressManager, vm.envBytes32("L2_GENESIS_HASH"))
            )
        );

        _deploy("tier_provider", address(new TaikoA6TierProvider()), "");

        // GuardianVerifier
        _deploy(
            "tier_guardian",
            address(new GuardianVerifier()),
            bytes.concat(GuardianVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        // SgxVerifier
        _deploy(
            "tier_sgx",
            address(new SgxVerifier()),
            bytes.concat(SgxVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        // SgxAndZkVerifier
        _deploy(
            "tier_sgx_and_pse_zkevm",
            address(new SgxAndZkVerifier()),
            bytes.concat(SgxAndZkVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        // PseZkVerifier
        address pseZkVerifier = _deploy(
            "tier_pse_zkevm",
            address(new PseZkVerifier()),
            bytes.concat(PseZkVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        address[] memory plonkVerifiers = new address[](1);
        plonkVerifiers[0] = _deployYulContract("contracts/L1/verifiers/PlonkVerifier.yulp");

        for (uint16 i = 0; i < plonkVerifiers.length; ++i) {
            _register(PseZkVerifier(pseZkVerifier).getVerifierName(i), plonkVerifiers[i]);
        }

        // Guardian prover
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
    }

    function _deployYulContract(string memory contractPath) private returns (address) {
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

        address deployedAddress;
        assembly {
            deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        if (deployedAddress == address(0)) {
            revert FAILED_TO_DEPLOY_PLONK_VERIFIER(contractPath);
        }

        console2.log(contractPath, deployedAddress);

        return deployedAddress;
    }
}
