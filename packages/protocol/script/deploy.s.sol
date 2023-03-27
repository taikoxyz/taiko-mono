// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../contracts/L1/TaikoToken.sol";
import "../contracts/L1/TaikoL1.sol";
import "../contracts/bridge/Bridge.sol";
import "../contracts/bridge/TokenVault.sol";
import "../contracts/signal/SignalService.sol";
import "../contracts/thirdparty/AddressManager.sol";
import "../contracts/test/erc20/FreeMintERC20.sol";
import "../contracts/test/erc20/MayFailFreeMintERC20.sol";

// forge script script/deploy.s.sol:DeployOnL1 \
// --rpc-url [url] \
// --broadcast --verify -vvvv \
contract DeployOnL1 is Script {
    function run() external {
        string memory l2ChainId = vm.envString("L2_CHAIN_ID");
        bytes32 l2GensisHash = vm.envBytes32("L2_GENESIS_HASH");
        address taikoL2Address = vm.envAddress("TAIKO_L2_ADDRESS");
        address oracleProver = vm.envAddress("ORACLE_PROVER_ADDRESS");
        address soloProposer = vm.envAddress("SOLO_PROPOSER");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        string memory l1ChainId = vm.toString(block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // AddressManager
        AddressManager addressManager = new AddressManager();
        addressManager.init();
        addressManager.setAddress(
            string.concat(l2ChainId, ".taiko"),
            taikoL2Address
        );

        // TaikoToken
        TaikoToken taikoToken = new TaikoToken();
        address[] memory premintRecipients = new address[](0);
        uint256[] memory premintAmounts = new uint256[](0);
        taikoToken.init(
            address(addressManager),
            "Taiko Token",
            "TKO",
            premintRecipients,
            premintAmounts
        );

        // HorseToken && BullToken
        new FreeMintERC20("Horse Token", "HORSE");
        new MayFailFreeMintERC20("Bull Token", "BLL");

        // TaikoL1
        TaikoL1 taikoL1 = new TaikoL1();
        uint64 feeBase = 10 ** 18;
        taikoL1.init(address(addressManager), l2GensisHash, feeBase);
        // Used by TaikoToken
        addressManager.setAddress(
            string.concat(l1ChainId, ".proto_broker"),
            address(taikoL1)
        );
        // Used by LibBridgeRead
        addressManager.setAddress(
            string.concat(l1ChainId, ".taiko"),
            address(taikoL1)
        );

        // Bridge
        Bridge bridge = new Bridge();
        bridge.init(address(addressManager));

        TokenVault tokenVault = new TokenVault();
        tokenVault.init(address(addressManager));

        // Used by TokenVault
        addressManager.setAddress(
            string.concat(l1ChainId, ".bridge"),
            address(bridge)
        );

        // SignalService
        SignalService signalService = new SignalService();
        signalService.init(address(addressManager));

        // Used by Bridge
        addressManager.setAddress(
            string.concat(l1ChainId, ".signal_service"),
            address(signalService)
        );

        // PlonkVerifier
        deployPlonkVerifiers(addressManager);

        if (oracleProver != address(0)) {
            addressManager.setAddress(
                string.concat(l1ChainId, ".oracle_prover"),
                oracleProver
            );
        }
        if (soloProposer != address(0)) {
            addressManager.setAddress(
                string.concat(l1ChainId, ".solo_proposer"),
                soloProposer
            );
        }

        vm.stopBroadcast();
    }

    function deployPlonkVerifiers(AddressManager addressManager) internal {
        address[] memory plonkVerifiers = new address[](2);
        plonkVerifiers[0] = compileYulContract(
            "contracts/libs/yul/PlonkVerifier_10_txs.yulp"
        );
        plonkVerifiers[1] = compileYulContract(
            "contracts/libs/yul/PlonkVerifier_80_txs.yulp"
        );

        for (uint256 i = 0; i < plonkVerifiers.length; ++i) {
            addressManager.setAddress(
                string(abi.encodePacked("verifier_", i)),
                plonkVerifiers[i]
            );
        }
    }

    function compileYulContract(
        string memory contractPath
    ) internal returns (address) {
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

        require(
            deployedAddress != address(0),
            string.concat("failed to deploy: ", contractPath)
        );

        return deployedAddress;
    }
}
