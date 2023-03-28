// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../contracts/L1/TaikoToken.sol";
import "../contracts/L1/TaikoL1.sol";
import "../contracts/bridge/Bridge.sol";
import "../contracts/bridge/TokenVault.sol";
import "../contracts/signal/SignalService.sol";
import "../contracts/thirdparty/AddressManager.sol";
import "../contracts/test/erc20/FreeMintERC20.sol";
import "../contracts/test/erc20/MayFailFreeMintERC20.sol";

contract DeployOnL1 is Script {
    error FAILED_TO_DEPLOY_PLONK_VERIFIER(string contractPath);

    function run() external {
        string memory l1ChainId = vm.toString(block.chainid);
        string memory l2ChainId = vm.envString("L2_CHAIN_ID");
        bytes32 l2GensisHash = vm.envBytes32("L2_GENESIS_HASH");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address taikoL2Address = vm.envAddress("TAIKO_L2_ADDRESS");
        address proxyAdmin = vm.envAddress("PROXY_ADMIN");
        address oracleProver = vm.envAddress("ORACLE_PROVER_ADDRESS");
        address soloProposer = vm.envAddress("SOLO_PROPOSER");
        address taikoTokenPremintRecipient = vm.envAddress(
            "TAIKO_TOKEN_PREMINT_RECIPIENT"
        );
        uint256 taikoTokenPremintAmount = vm.envUint(
            "TAIKO_TOKEN_PREMINT_AMOUNT"
        );

        vm.startBroadcast(deployerPrivateKey);

        // AddressManager
        AddressManager addressManager = new AddressManager();
        address addressManagerProxy = deployUupsProxy(
            address(addressManager),
            proxyAdmin,
            bytes.concat(addressManager.init.selector)
        );
        AddressManager(addressManagerProxy).setAddress(
            string.concat(l2ChainId, ".taiko"),
            taikoL2Address
        );
        console.log("AddressManager:", address(addressManager));
        console.log("AddressManagerProxy:", addressManagerProxy);

        // TaikoToken
        TaikoToken taikoToken = new TaikoToken();

        address[] memory premintRecipients = new address[](1);
        uint256[] memory premintAmounts = new uint256[](1);
        premintRecipients[0] = taikoTokenPremintRecipient;
        premintAmounts[0] = taikoTokenPremintAmount;

        address taikoTokenProxy = deployUupsProxy(
            address(taikoToken),
            proxyAdmin,
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
        console.log("TaikoToken:", address(taikoToken));
        console.log("TaikoTokenProxy:", taikoTokenProxy);

        // HorseToken && BullToken
        FreeMintERC20 horseToken = new FreeMintERC20("Horse Token", "HORSE");
        MayFailFreeMintERC20 bullToken = new MayFailFreeMintERC20(
            "Bull Token",
            "BLL"
        );
        console.log("HorseToken:", address(horseToken));
        console.log("BullToken:", address(bullToken));

        // TaikoL1
        TaikoL1 taikoL1 = new TaikoL1();
        uint64 feeBase = 10 ** 18;
        address taikoL1Proxy = deployUupsProxy(
            address(taikoL1),
            proxyAdmin,
            bytes.concat(
                taikoL1.init.selector,
                abi.encode(addressManagerProxy, l2GensisHash, feeBase)
            )
        );
        console.log("TaikoL1:", address(taikoL1));
        console.log("TaikoL1Proxy:", taikoL1Proxy);

        // Used by TaikoToken
        AddressManager(addressManagerProxy).setAddress(
            string.concat(l1ChainId, ".proto_broker"),
            address(taikoL1Proxy)
        );
        // Used by LibBridgeRead
        AddressManager(addressManagerProxy).setAddress(
            string.concat(l1ChainId, ".taiko"),
            address(taikoL1Proxy)
        );

        // Bridge
        Bridge bridge = new Bridge();
        address bridgeProxy = deployUupsProxy(
            address(bridge),
            proxyAdmin,
            bytes.concat(bridge.init.selector, abi.encode(addressManagerProxy))
        );
        console.log("Bridge:", address(bridge));
        console.log("BridgeProxy:", bridgeProxy);

        TokenVault tokenVault = new TokenVault();
        address tokenVaultProxy = deployUupsProxy(
            address(tokenVault),
            proxyAdmin,
            bytes.concat(
                tokenVault.init.selector,
                abi.encode(addressManagerProxy)
            )
        );
        console.log("TokenVault:", address(tokenVault));
        console.log("TokenVaultProxy:", tokenVaultProxy);

        // Used by TokenVault
        AddressManager(addressManagerProxy).setAddress(
            string.concat(l1ChainId, ".bridge"),
            bridgeProxy
        );

        // SignalService
        SignalService signalService = new SignalService();
        address signalServiceProxy = deployUupsProxy(
            address(signalService),
            proxyAdmin,
            bytes.concat(
                signalService.init.selector,
                abi.encode(addressManagerProxy)
            )
        );
        console.log("SignalService:", address(signalService));
        console.log("SignalServiceProxy:", signalServiceProxy);

        // Used by Bridge
        AddressManager(addressManagerProxy).setAddress(
            string.concat(l1ChainId, ".signal_service"),
            address(signalServiceProxy)
        );

        // PlonkVerifier
        deployPlonkVerifiers(addressManagerProxy);

        if (oracleProver != address(0)) {
            AddressManager(addressManagerProxy).setAddress(
                string.concat(l1ChainId, ".oracle_prover"),
                oracleProver
            );
        }
        if (soloProposer != address(0)) {
            AddressManager(addressManagerProxy).setAddress(
                string.concat(l1ChainId, ".solo_proposer"),
                soloProposer
            );
        }

        vm.stopBroadcast();
    }

    function deployPlonkVerifiers(address addressManagerProxy) internal {
        address[] memory plonkVerifiers = new address[](2);
        plonkVerifiers[0] = deployYulContract(
            "contracts/libs/yul/PlonkVerifier_10_txs.yulp"
        );
        plonkVerifiers[1] = deployYulContract(
            "contracts/libs/yul/PlonkVerifier_80_txs.yulp"
        );

        for (uint256 i = 0; i < plonkVerifiers.length; ++i) {
            AddressManager(addressManagerProxy).setAddress(
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

        console.log(string.concat(contractPath, ":"), deployedAddress);

        return deployedAddress;
    }

    function deployUupsProxy(
        address implementation,
        address admin,
        bytes memory data
    ) private returns (address) {
        return
            address(
                new TransparentUpgradeableProxy(implementation, admin, data)
            );
    }
}
