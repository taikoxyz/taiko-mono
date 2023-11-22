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
contract DeployOnL1 is Script {
    uint256 public constant NUM_GUARDIANS = 5;

    error FAILED_TO_DEPLOY_PLONK_VERIFIER(string contractPath);

    struct Ctx {
        address addressManager;
        address owner;
        uint64 chainId;
    }

    Ctx internal ctx;

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        address bridgeAddressManager = deployBridgeSuite();
        address rollupAddressManager = deployTaikoL1Suite(bridgeAddressManager);

        // Authorize the new TaikoL1 contract for shared signal service.
        // TODO
        // ProxiedSingletonSignalService(signalService).authorize(taikoL1Proxy,
        // bytes32(block.chainid));

        ctx.addressManager = rollupAddressManager;

        address proposer = vm.envAddress("PROPOSER");
        if (proposer != address(0)) {
            register("proposer", proposer);
        }

        address proposerOne = vm.envAddress("PROPOSER_ONE");
        if (proposerOne != address(0)) {
            register("proposer_one", proposerOne);
        }

        TaikoL1 taikoL1 = TaikoL1(
            payable(AddressManager(rollupAddressManager).getAddress(uint64(block.chainid), "taiko"))
        );

        uint64 l2ChainId = taikoL1.getConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        ctx.chainId = l2ChainId;
        register("taiko", vm.envAddress("TAIKO_L2_ADDRESS"));
        register("signal_service", vm.envAddress("L2_SIGNAL_SERVICE"));

        address horseToken = address(new FreeMintERC20("Horse Token", "HORSE"));
        console2.log("HorseToken", horseToken);

        vm.stopBroadcast();
    }

    function deploy(
        bytes32 name,
        address implementation,
        bytes memory data
    )
        private
        returns (address proxy)
    {
        require(ctx.owner != address(0), "null owner");
        proxy =
            LibDeploy.deployTransparentUpgradeableProxyForOwnable(implementation, ctx.owner, data);

        if (ctx.addressManager != address(0)) {
            AddressManager(ctx.addressManager).setAddress(ctx.chainId, name, proxy);
            // console2.log(strings.concat(name, ": ", proxy, " =>", implementation));
        } else {
            // console2.log(name, ": ", proxy, " ->", implementation);
        }

        // vm.writeJson(
        //     vm.serializeAddress("deployment", name, proxy),
        //     string.concat(vm.projectRoot(), "/deployments/deploy_l1.json")
        // );
    }

    function register(bytes32 name, address addr) private {
        require(ctx.addressManager != address(0), "null manager");
        require(addr != address(0), "null address");
        AddressManager(ctx.addressManager).setAddress(ctx.chainId, name, addr);
        // console2.log(strings.concat(name, ": ", proxy, " =>", implementation));
    }

    function registerFrom(bytes32 name, address srcAddressManager) private {
        require(srcAddressManager != address(0), "null src manager");
        register(name, AddressManager(srcAddressManager).getAddress(ctx.chainId, name));
    }

    function deployBridgeSuite() internal returns (address bridgeAddressManager) {
        address _bridgeAddressManager = vm.envAddress("BRIDGE_ADDRESS_MANAGER");
        if (_bridgeAddressManager != address(0)) {
            return _bridgeAddressManager;
        }

        ctx.addressManager = address(0);
        ctx.chainId = uint64(block.chainid);
        ctx.owner = vm.envAddress("OWNER");
        require(ctx.owner != address(0), "invalid owner");

        bridgeAddressManager = deploy(
            "address_manager_for_bridge",
            address(new ProxiedAddressManager()),
            bytes.concat(AddressManager.init.selector)
        );

        ctx.addressManager = bridgeAddressManager;

        deploy(
            "signal_service",
            address(new ProxiedSingletonSignalService()),
            bytes.concat(SignalService.init.selector, abi.encode(ctx.addressManager))
        );

        deploy(
            "bridge",
            address(new ProxiedSingletonBridge()),
            bytes.concat(Bridge.init.selector, abi.encode(ctx.addressManager))
        );

        register("proxied_bridged_erc20", address(new ProxiedBridgedERC20()));
        deploy(
            "erc20_vault",
            address(new ProxiedSingletonERC20Vault()),
            bytes.concat(BaseVault.init.selector, abi.encode(ctx.addressManager))
        );

        register("proxied_bridged_erc721", address(new ProxiedBridgedERC721()));
        deploy(
            "erc721_vault",
            address(new ProxiedSingletonERC721Vault()),
            bytes.concat(BaseVault.init.selector, abi.encode(ctx.addressManager))
        );

        register("proxied_bridged_erc1155", address(new ProxiedBridgedERC1155()));
        deploy(
            "erc1155_vault",
            address(new ProxiedSingletonERC1155Vault()),
            bytes.concat(BaseVault.init.selector, abi.encode(ctx.addressManager))
        );
    }

    function deployTaikoL1Suite(address _bridgeAddressManager)
        internal
        returns (address rollupAddressManager)
    {
        ctx.addressManager = address(0);
        ctx.chainId = uint64(block.chainid);
        ctx.owner = vm.envAddress("OWNER");
        require(ctx.owner != address(0), "invalid owner");

        rollupAddressManager = deploy(
            "address_manager_for_rollup",
            address(new ProxiedAddressManager()),
            bytes.concat(AddressManager.init.selector)
        );

        ctx.addressManager = rollupAddressManager;

        registerFrom("bridge", _bridgeAddressManager);
        registerFrom("signal_service", _bridgeAddressManager);

        deploy(
            "taiko_token",
            address(new ProxiedTaikoToken()),
            bytes.concat(
                TaikoToken.init.selector,
                abi.encode(
                    ctx.addressManager,
                    "Taiko Token Katla",
                    "TTKOk",
                    vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT")
                )
            )
        );

        deploy(
            "taiko",
            address(new ProxiedTaikoL1()),
            bytes.concat(
                TaikoL1.init.selector,
                abi.encode(ctx.addressManager, vm.envBytes32("L2_GENESIS_HASH"))
            )
        );

        deploy("tier_provider", address(new TaikoA6TierProvider()), "");

        // GuardianVerifier
        deploy(
            "tier_guardian",
            address(new ProxiedGuardianVerifier()),
            bytes.concat(GuardianVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        // SgxVerifier
        deploy(
            "tier_sgx",
            address(new ProxiedSgxVerifier()),
            bytes.concat(SgxVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        // SgxAndZkVerifier
        deploy(
            "tier_sgx_and_pse_zkevm",
            address(new ProxiedSgxAndZkVerifier()),
            bytes.concat(SgxAndZkVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        // PseZkVerifier
        address pseZkVerifier = deploy(
            "tier_pse_zkevm",
            address(new ProxiedPseZkVerifier()),
            bytes.concat(PseZkVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        address[] memory plonkVerifiers = new address[](1);
        plonkVerifiers[0] = deployYulContract("contracts/L1/verifiers/PlonkVerifier.yulp");

        for (uint16 i = 0; i < plonkVerifiers.length; ++i) {
            register(PseZkVerifier(pseZkVerifier).getVerifierName(i), plonkVerifiers[i]);
        }

        // Guardian prover
        address guardianProver = deploy(
            "guardian_prover",
            address(new ProxiedGuardianProver()),
            bytes.concat(GuardianProver.init.selector, abi.encode(ctx.addressManager))
        );

        address[] memory guardianProvers = vm.envAddress("GUARDIAN_PROVERS", ",");
        require(guardianProvers.length == NUM_GUARDIANS, "invalid guardian provers number");

        address[NUM_GUARDIANS] memory guardians;
        for (uint256 i = 0; i < NUM_GUARDIANS; ++i) {
            guardians[i] = guardianProvers[i];
        }
        GuardianProver(guardianProver).setGuardians(guardians);
    }

    function deployYulContract(string memory contractPath) private returns (address) {
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
