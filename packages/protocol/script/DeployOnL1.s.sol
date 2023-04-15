// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "../contracts/common/AddressResolver.sol";
import "../contracts/L1/TaikoToken.sol";
import "../contracts/L1/TaikoL1.sol";
import "../contracts/bridge/Bridge.sol";
import "../contracts/bridge/TokenVault.sol";
import "../contracts/signal/SignalService.sol";
import "../contracts/thirdparty/AddressManager.sol";
import "../contracts/test/erc20/FreeMintERC20.sol";
import "../contracts/test/erc20/MayFailFreeMintERC20.sol";

contract DeployOnL1 is Script, AddressResolver {
    using SafeCastUpgradeable for uint256;
    uint256 public l2ChainId = vm.envUint("L2_CHAIN_ID");

    bytes32 public gensisHash = vm.envBytes32("L2_GENESIS_HASH");

    uint256 public deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    address public taikoL2Address = vm.envAddress("TAIKO_L2_ADDRESS");

    address public owner = vm.envAddress("OWNER");

    address public oracleProver = vm.envAddress("ORACLE_PROVER");

    address public soloProposer = vm.envAddress("SOLO_PROPOSER");

    address public sharedSignalService = vm.envAddress("SHARED_SIGNAL_SERVICE");

    address public treasure = vm.envAddress("TREASURE");

    address public taikoTokenPremintRecipient =
        vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT");

    uint256 public taikoTokenPremintAmount =
        vm.envUint("TAIKO_TOKEN_PREMINT_AMOUNT");

    address public addressManagerProxy;

    error FAILED_TO_DEPLOY_PLONK_VERIFIER(string contractPath);

    function run() external {
        require(l2ChainId != block.chainid, "same chainid");
        require(owner != address(0), "owner is zero");
        require(taikoL2Address != address(0), "taikoL2Address is zero");
        require(treasure != address(0), "treasure is zero");
        require(
            taikoTokenPremintRecipient != address(0),
            "taikoTokenPremintRecipient is zero"
        );
        require(
            taikoTokenPremintAmount < type(uint64).max,
            "premint too large"
        );

        vm.startBroadcast(deployerPrivateKey);

        // AddressManager
        AddressManager addressManager = new AddressManager();
        addressManagerProxy = deployProxy(
            "address_manager",
            address(addressManager),
            bytes.concat(addressManager.init.selector)
        );

        setAddress(l2ChainId, "taiko", taikoL2Address);
        setAddress("oracle_prover", oracleProver);
        setAddress("solo_proposer", soloProposer);
        setAddress(l2ChainId, "treasure", treasure);

        // TaikoToken
        TaikoToken taikoToken = new TaikoToken();

        address[] memory premintRecipients = new address[](1);
        uint256[] memory premintAmounts = new uint256[](1);
        premintRecipients[0] = taikoTokenPremintRecipient;
        premintAmounts[0] = taikoTokenPremintAmount;

        deployProxy(
            "taiko_token",
            address(taikoToken),
            bytes.concat(
                taikoToken.init.selector,
                abi.encode(
                    addressManagerProxy,
                    "Taiko Token",
                    "TKO",
                    premintRecipients,
                    premintAmounts
                )
            )
        );

        // HorseToken && BullToken
        address horseToken = address(new FreeMintERC20("Horse Token", "HORSE"));
        console.log("HorseToken", horseToken);

        address bullToken = address(
            new MayFailFreeMintERC20("Bull Token", "BLL")
        );
        console.log("BullToken", bullToken);

        // Bridge
        Bridge bridge = new Bridge();
        deployProxy(
            "bridge",
            address(bridge),
            bytes.concat(bridge.init.selector, abi.encode(addressManagerProxy))
        );

        // TokenVault
        TokenVault tokenVault = new TokenVault();
        deployProxy(
            "token_vault",
            address(tokenVault),
            bytes.concat(
                tokenVault.init.selector,
                abi.encode(addressManagerProxy)
            )
        );

        // SignalService
        if (sharedSignalService == address(0)) {
            SignalService signalService = new SignalService();
            deployProxy(
                "signal_service",
                address(signalService),
                bytes.concat(
                    signalService.init.selector,
                    abi.encode(addressManagerProxy)
                )
            );
        } else {
            console.log(
                "Warining: using shared signal service: ",
                sharedSignalService
            );
            setAddress("signal_service", sharedSignalService);
        }

        // TaikoL1
        // Only deploy after "signal_service"s and "taiko_l2" addresses have
        // been registered
        TaikoL1 taikoL1 = new TaikoL1();

        uint64 feeBase = 1 ** 8; // Taiko Token's decimals is 8, not 18
        address taikoL1Proxy = deployProxy(
            "taiko",
            address(taikoL1),
            bytes.concat(
                taikoL1.init.selector,
                abi.encode(addressManagerProxy, feeBase, gensisHash)
            )
        );
        setAddress("proto_broker", taikoL1Proxy);

        // PlonkVerifier
        deployPlonkVerifiers();

        vm.stopBroadcast();
    }

    function deployPlonkVerifiers() private {
        address[] memory plonkVerifiers = new address[](2);
        plonkVerifiers[0] = deployYulContract(
            "contracts/libs/yul/PlonkVerifier_10_txs.yulp"
        );
        plonkVerifiers[1] = deployYulContract(
            "contracts/libs/yul/PlonkVerifier_80_txs.yulp"
        );

        for (uint16 i = 0; i < plonkVerifiers.length; ++i) {
            setAddress(
                string(abi.encodePacked("verifier_", i)),
                plonkVerifiers[i]
            );
        }
    }

    function deployYulContract(
        string memory contractPath
    ) private returns (address) {
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

        if (deployedAddress == address(0))
            revert FAILED_TO_DEPLOY_PLONK_VERIFIER(contractPath);

        console.log(contractPath, deployedAddress);

        return deployedAddress;
    }

    function deployProxy(
        string memory name,
        address implementation,
        bytes memory data
    ) private returns (address proxy) {
        proxy = address(
            new TransparentUpgradeableProxy(implementation, owner, data)
        );

        console.log(name, "(impl) ->", implementation);
        console.log(name, "(proxy) ->", proxy);

        if (addressManagerProxy != address(0)) {
            AddressManager(addressManagerProxy).setAddress(
                keyForName(block.chainid, name),
                proxy
            );
        }
    }

    function setAddress(string memory name, address addr) private {
        setAddress(block.chainid, name, addr);
    }

    function setAddress(
        uint256 chainId,
        string memory name,
        address addr
    ) private {
        console.log(chainId, name, "--->", addr);
        if (addr != address(0)) {
            AddressManager(addressManagerProxy).setAddress(
                keyForName(chainId, name),
                addr
            );
        }
    }
}
