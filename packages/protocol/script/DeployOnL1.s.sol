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

import "../contracts/L1/TaikoToken.sol";
import "../contracts/L1/TaikoL1.sol";
import "../contracts/L1/provers/GuardianProver.sol";
import "../contracts/L1/verifiers/PseZkVerifier.sol";
import "../contracts/L1/verifiers/SgxVerifier.sol";
import "../contracts/L1/verifiers/SgxAndZkVerifier.sol";
import "../contracts/L1/verifiers/GuardianVerifier.sol";
import "../contracts/L1/tiers/ITierProvider.sol";
import "../contracts/L1/tiers/TaikoA6TierProvider.sol";
import "../contracts/bridge/Bridge.sol";
import "../contracts/tokenvault/BridgedERC20.sol";
import "../contracts/tokenvault/BridgedERC721.sol";
import "../contracts/tokenvault/BridgedERC1155.sol";
import "../contracts/tokenvault/ERC20Vault.sol";
import "../contracts/tokenvault/ERC1155Vault.sol";
import "../contracts/tokenvault/ERC721Vault.sol";
import "../contracts/signal/SignalService.sol";
import "../contracts/common/AddressManager.sol";
import "../contracts/libs/LibDeploy.sol";
import "../contracts/test/erc20/FreeMintERC20.sol";
import "../contracts/test/erc20/MayFailFreeMintERC20.sol";

/// @title DeployOnL1
/// @notice This script deploys the core Taiko protocol smart contract on L1,
/// initializing the rollup.
contract DeployOnL1 is Script {
    // NOTE: this value must match the constant defined in GuardianProver.sol
    uint256 public constant NUM_GUARDIANS = 5;

    bytes32 public genesisHash = vm.envBytes32("L2_GENESIS_HASH");

    uint256 public deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    address public taikoL2Address = vm.envAddress("TAIKO_L2_ADDRESS");

    address public l2SignalService = vm.envAddress("L2_SIGNAL_SERVICE");

    address public owner = vm.envAddress("OWNER");

    address[] public guardianProvers = vm.envAddress("GUARDIAN_PROVERS", ",");

    address public proposer = vm.envAddress("PROPOSER");

    address public proposerOne = vm.envAddress("PROPOSER_ONE");

    address public singletonBridge = vm.envAddress("SINGLETON_BRIDGE");

    address public signalService = vm.envAddress("SIGNAL_SERVICE");

    uint256 public tierProvider = vm.envUint("TIER_PROVIDER");

    address public taikoTokenPremintRecipient = vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT");

    TaikoL1 taikoL1;
    address public rollupAddressManager;

    enum TierProviders { TAIKO_ALPHA6 }

    error FAILED_TO_DEPLOY_PLONK_VERIFIER(string contractPath);

    function run() external {
        require(owner != address(0), "owner is zero");
        require(taikoL2Address != address(0), "taikoL2Address is zero");
        require(l2SignalService != address(0), "l2SignalService is zero");
        require(guardianProvers.length == NUM_GUARDIANS, "invalid guardian provers number");
        if (singletonBridge == address(0)) {
            require(signalService == address(0), "non-empty singleton signal service address");
        } else {
            require(signalService != address(0), "empty singleton signal service address");
        }
        vm.startBroadcast(deployerPrivateKey);

        // AddressManager for TaikoL1
        rollupAddressManager = deployProxy(
            "address_manager",
            address(new ProxiedAddressManager()),
            bytes.concat(AddressManager.init.selector)
        );

        // TaikoL1
        taikoL1 = new ProxiedTaikoL1();
        uint64 l2ChainId = taikoL1.getConfig().chainId;
        require(l2ChainId != block.chainid, "same chainid");

        setAddress(l2ChainId, "taiko", taikoL2Address);
        setAddress(l2ChainId, "signal_service", l2SignalService);
        if (proposer != address(0)) {
            setAddress("proposer", proposer);
        }
        if (proposerOne != address(0)) {
            setAddress("proposer_one", proposer);
        }

        // TaikoToken
        TaikoToken taikoToken = new ProxiedTaikoToken();

        deployProxy(
            "taiko_token",
            address(taikoToken),
            bytes.concat(
                taikoToken.init.selector,
                abi.encode(
                    rollupAddressManager, "Taiko Token Katla", "TTKOk", taikoTokenPremintRecipient
                )
            )
        );

        // HorseToken
        address horseToken = address(new FreeMintERC20("Horse Token", "HORSE"));
        console2.log("HorseToken", horseToken);

        address taikoL1Proxy = deployProxy(
            "taiko",
            address(taikoL1),
            bytes.concat(taikoL1.init.selector, abi.encode(rollupAddressManager, genesisHash))
        );
        setAddress("taiko", taikoL1Proxy);

        // All bridging related contracts should be deployed as a singleton on
        // each chain.
        if (singletonBridge == address(0)) {
            deployBridgeSuiteSingletons();
        }

        // Bridge and SignalService addresses will be used by TaikoL1.
        setAddress("bridge", singletonBridge);
        setAddress("signal_service", signalService);

        // Authorize the new TaikoL1 contract for shared signal service.
        ProxiedSingletonSignalService(signalService).authorize(taikoL1Proxy, bytes32(block.chainid));

        // Guardian prover
        ProxiedGuardianProver guardianProver = new ProxiedGuardianProver();
        address guardianProverProxy = deployProxy(
            "guardian_prover",
            address(guardianProver),
            bytes.concat(guardianProver.init.selector, abi.encode(rollupAddressManager))
        );
        address[NUM_GUARDIANS] memory guardians;
        for (uint256 i = 0; i < NUM_GUARDIANS; ++i) {
            guardians[i] = guardianProvers[i];
        }
        ProxiedGuardianProver(guardianProverProxy).setGuardians(guardians);

        // Config provider
        deployProxy("tier_provider", deployTierProvider(uint256(TierProviders.TAIKO_ALPHA6)), "");

        // GuardianVerifier
        GuardianVerifier guardianVerifier = new ProxiedGuardianVerifier();
        deployProxy(
            "tier_guardian",
            address(guardianVerifier),
            bytes.concat(guardianVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        // SgxVerifier
        SgxVerifier sgxVerifier = new ProxiedSgxVerifier();
        deployProxy(
            "tier_sgx",
            address(sgxVerifier),
            bytes.concat(sgxVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        // SgxAndZkVerifier
        SgxAndZkVerifier sgxAndZkVerifier = new ProxiedSgxAndZkVerifier();
        deployProxy(
            "tier_sgx_and_pse_zkevm",
            address(sgxAndZkVerifier),
            bytes.concat(sgxVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        // PseZkVerifier
        PseZkVerifier pseZkVerifier = new ProxiedPseZkVerifier();
        deployProxy(
            "tier_pse_zkevm",
            address(pseZkVerifier),
            bytes.concat(pseZkVerifier.init.selector, abi.encode(rollupAddressManager))
        );

        // PlonkVerifier
        deployPlonkVerifiers(pseZkVerifier);

        vm.stopBroadcast();
    }

    function deployPlonkVerifiers(PseZkVerifier pseZkVerifier) private {
        address[] memory plonkVerifiers = new address[](1);
        plonkVerifiers[0] = deployYulContract("contracts/L1/verifiers/PlonkVerifier.yulp");

        for (uint16 i = 0; i < plonkVerifiers.length; ++i) {
            setAddress(pseZkVerifier.getVerifierName(i), plonkVerifiers[i]);
        }
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

    function deployTierProvider(uint256 tier) private returns (address providerAddress) {
        if (tier == uint256(TierProviders.TAIKO_ALPHA6)) {
            return address(new TaikoA6TierProvider());
        }

        revert("invalid provider");
    }

    function deployBridgeSuiteSingletons() private {
        // AddressManager
        AddressManager addressManagerForSingletons = new ProxiedAddressManager();
        address addressManager = deployProxy(
            address(0),
            "address_manager_for_singletons",
            address(addressManagerForSingletons),
            bytes.concat(addressManagerForSingletons.init.selector)
        );

        // Bridge
        Bridge bridge = new ProxiedSingletonBridge();
        singletonBridge = deployProxy(
            addressManager,
            "bridge",
            address(bridge),
            bytes.concat(bridge.init.selector, abi.encode(addressManager))
        );

        // ERC20Vault
        ERC20Vault erc20Vault = new ProxiedSingletonERC20Vault();
        deployProxy(
            addressManager,
            "erc20_vault",
            address(erc20Vault),
            bytes.concat(erc20Vault.init.selector, abi.encode(addressManager))
        );

        // ERC721Vault
        ERC721Vault erc721Vault = new ProxiedSingletonERC721Vault();
        deployProxy(
            addressManager,
            "erc721_vault",
            address(erc721Vault),
            bytes.concat(erc721Vault.init.selector, abi.encode(addressManager))
        );

        // ERC1155Vault
        ERC1155Vault erc1155Vault = new ProxiedSingletonERC1155Vault();
        deployProxy(
            addressManager,
            "erc1155_vault",
            address(erc1155Vault),
            bytes.concat(erc1155Vault.init.selector, abi.encode(addressManager))
        );

        // SignalService
        signalService = deployProxy(
            addressManager,
            "signal_service",
            address(new ProxiedSingletonSignalService()),
            bytes.concat(SignalService.init.selector, abi.encode(addressManager))
        );

        // Deploy ProxiedBridged token contracts
        setAddress(
            addressManager,
            uint64(block.chainid),
            "proxied_bridged_erc20",
            address(new ProxiedBridgedERC20())
        );
        setAddress(
            addressManager,
            uint64(block.chainid),
            "proxied_bridged_erc721",
            address(new ProxiedBridgedERC721())
        );
        setAddress(
            addressManager,
            uint64(block.chainid),
            "proxied_bridged_erc1155",
            address(new ProxiedBridgedERC1155())
        );
    }

    function deployProxy(
        string memory name,
        address implementation,
        bytes memory data
    )
        private
        returns (address proxy)
    {
        return deployProxy(rollupAddressManager, name, implementation, data);
    }

    function deployProxy(
        address addressManager,
        string memory name,
        address implementation,
        bytes memory data
    )
        private
        returns (address proxy)
    {
        proxy = LibDeploy.deployTransparentUpgradeableProxyForOwnable(implementation, owner, data);

        console2.log(name, "(impl) ->", implementation);
        console2.log(name, "(proxy) ->", proxy);

        setAddress(addressManager, uint64(block.chainid), bytes32(bytes(name)), proxy);

        vm.writeJson(
            vm.serializeAddress("deployment", name, proxy),
            string.concat(vm.projectRoot(), "/deployments/deploy_l1.json")
        );
    }

    function setAddress(bytes32 name, address addr) private {
        setAddress(rollupAddressManager, uint64(block.chainid), name, addr);
    }

    function setAddress(uint256 chainId, bytes32 name, address addr) private {
        setAddress(rollupAddressManager, uint64(chainId), name, addr);
    }

    function setAddress(
        address addressManager,
        uint64 chainId,
        bytes32 name,
        address addr
    )
        private
    {
        if (addressManager != address(0) && addr != address(0)) {
            console2.log(chainId, uint256(name), "--->", addr);
            AddressManager(addressManager).setAddress(chainId, name, addr);
        }
    }
}
