// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/forced-inclusion/TaikoWrapper.sol";
import "src/layer1/provers/ProverSet.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";

contract DeployWLAndWrapper is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address taikoInbox = 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
        address forcedInclusionStore = 0x05d88855361808fA1d7fc28084Ef3fCa191c4e03;
        address router = 0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a;
        address rollupResolver = 0x5A982Fb1818c22744f5d7D36D0C4c9f61937b33a;
        address taikoToken = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
        address taikoSequencer = 0x5F62d006C10C009ff50C878Cd6157aC861C99990;
        address ejector = 0x45D4403351Bc34283CE6450D91c099f40D06dA4e;
        address taikoWrapper = 0x9F9D2fC7abe74C79f86F0D1212107692430eef72;
        address whitelist = 0xFD019460881e6EeC632258222393d5821029b2ac;
        address fallbackProposer = 0x7A853a6480F4D7dB79AE91c16c960dBbB6710d25;
        address chainBoundSequencer = 0x000cb000E880A92a8f383D69dA2142a969B93DE7;

        address whitelistImpl = address(new PreconfWhitelist());
        console2.log(
            "Upgrading whitelist calldata: ",
            abi.encodeCall(UUPSUpgradeable.upgradeTo, (whitelistImpl))
        );
        console2.log(
            "Set ejector calldata: ", abi.encodeCall(PreconfWhitelist.setEjecter, (ejector, true))
        );

        console2.log(
            "Add taiko operator calldata: ",
            abi.encodeCall(PreconfWhitelist.addOperator, (taikoSequencer, taikoSequencer))
        );

        console2.log(
            "Add chainbound operator calldata: ",
            abi.encodeCall(PreconfWhitelist.addOperator, (chainBoundSequencer, chainBoundSequencer))
        );

        address router = address(new PreconfRouter(taikoWrapper, whitelist, fallbackProposer));
        console2.log(
            "Upgrading router calldata: ", abi.encodeCall(UUPSUpgradeable.upgradeTo, (router))
        );

        address wrapper = address(new TaikoWrapper(taikoInbox, forcedInclusionStore, router));
        console2.log(
            "Upgrading wrapper calldata: ", abi.encodeCall(UUPSUpgradeable.upgradeTo, (wrapper))
        );
    }
}
