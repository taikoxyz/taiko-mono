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
    string l1ChainId = vm.toString(block.chainid);
    string l2ChainId = vm.envString("L2_CHAIN_ID");
    bytes32 l2GensisHash = vm.envBytes32("L2_GENESIS_HASH");
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address taikoL2Address = vm.envAddress("TAIKO_L2_ADDRESS");
    address proxyAdmin = vm.envAddress("PROXY_ADMIN");
    address oracleProver = vm.envAddress("ORACLE_PROVER_ADDRESS");
    address soloProposer = vm.envAddress("SOLO_PROPOSER");
    address taikoTokenPremintRecipient =
        vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT");
    uint256 taikoTokenPremintAmount = vm.envUint("TAIKO_TOKEN_PREMINT_AMOUNT");
    address addressManagerProxy;

    error FAILED_TO_DEPLOY_PLONK_VERIFIER(string contractPath);

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        // AddressManager
        AddressManager addressManager = new AddressManager();
        addressManagerProxy = deployUupsProxy(
            "AddressManager",
            address(addressManager),
            proxyAdmin,
            bytes.concat(addressManager.init.selector)
        );

        setAddressWithCustomChainId(l2ChainId, "taiko", taikoL2Address);

        if (oracleProver != address(0)) {
            setAddress("oracle_prover", oracleProver);
        }
        if (soloProposer != address(0)) {
            setAddress("solo_proposer", soloProposer);
        }

        // TaikoToken
        TaikoToken taikoToken = new TaikoToken();

        address[] memory premintRecipients = new address[](1);
        uint256[] memory premintAmounts = new uint256[](1);
        premintRecipients[0] = taikoTokenPremintRecipient;
        premintAmounts[0] = taikoTokenPremintAmount;

        deployUupsProxy(
            "TaiToken",
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

        // HorseToken && BullToken
        FreeMintERC20 horseToken = new FreeMintERC20("Horse Token", "HORSE");
        MayFailFreeMintERC20 bullToken = new MayFailFreeMintERC20(
            "Bull Token",
            "BLL"
        );
        console.log("HorseToken", address(horseToken));
        console.log("BullToken", address(bullToken));

        // TaikoL1
        TaikoL1 taikoL1 = new TaikoL1();
        uint64 feeBase = 10 ** 18;
        address taikoL1Proxy = deployUupsProxy(
            "TaikoL1",
            address(taikoL1),
            proxyAdmin,
            bytes.concat(
                taikoL1.init.selector,
                abi.encode(addressManagerProxy, l2GensisHash, feeBase)
            )
        );

        // Used by TaikoToken
        setAddress("proto_broker", taikoL1Proxy);
        // Used by LibBridgeRead
        setAddress("taiko", taikoL1Proxy);

        // Bridge
        Bridge bridge = new Bridge();
        address bridgeProxy = deployUupsProxy(
            "Bridge",
            address(bridge),
            proxyAdmin,
            bytes.concat(bridge.init.selector, abi.encode(addressManagerProxy))
        );

        // TokenVault
        TokenVault tokenVault = new TokenVault();
        deployUupsProxy(
            "TokenVault",
            address(tokenVault),
            proxyAdmin,
            bytes.concat(
                tokenVault.init.selector,
                abi.encode(addressManagerProxy)
            )
        );

        // Used by TokenVault
        setAddress("bridge", bridgeProxy);

        // SignalService
        SignalService signalService = new SignalService();
        address signalServiceProxy = deployUupsProxy(
            "SignalService",
            address(signalService),
            proxyAdmin,
            bytes.concat(
                signalService.init.selector,
                abi.encode(addressManagerProxy)
            )
        );

        // Used by Bridge
        setAddress("signal_service", signalServiceProxy);

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

        for (uint256 i = 0; i < plonkVerifiers.length; ++i) {
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

    function deployUupsProxy(
        string memory name,
        address implementation,
        address admin,
        bytes memory data
    ) private returns (address) {
        address proxy = address(
            new TransparentUpgradeableProxy(implementation, admin, data)
        );

        console.log(name, implementation);
        console.log(string.concat(name, "Proxy"), proxy);

        return proxy;
    }

    // Address Manager
    function setAddress(string memory name, address addr) private {
        AddressManager(addressManagerProxy).setAddress(
            getAddressMangerKey(l1ChainId, name),
            addr
        );
    }

    function setAddressWithCustomChainId(
        string memory chainId,
        string memory name,
        address addr
    ) private {
        AddressManager(addressManagerProxy).setAddress(
            getAddressMangerKey(chainId, name),
            addr
        );
    }

    function getAddressMangerKey(
        string memory chainId,
        string memory name
    ) private pure returns (string memory) {
        return string.concat(chainId, ".", name);
    }
}
