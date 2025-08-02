// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/forced-inclusion/TaikoWrapper.sol";
import "src/layer1/provers/ProverSet.sol";

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
        address sequencer = 0x5F62d006C10C009ff50C878Cd6157aC861C99990;
        address ejecter = address(0); // TODO: need the ejecter address

        address whitelist = address(new PreconfWhitelist());
        console2.log(
            "Upgrading whitelist calldata: ", abi.encodeCall(UUPSUpgradeable.upgradeTo, (whitelist))
        );
        console2.log(
            "Set ejecter calldata: ", abi.encodeCall(PreconfWhitelist.setEjecter, (ejecter, true))
        );
        // TODO: confirm that we use the same address as _proposer and _sequencer
        // Note: Should be in the first batch by multi-sig
        console2.log(
            "Add operator calldata: ",
            abi.encodeCall(PreconfWhitelist.addOperator, (sequencer, sequencer))
        );

        address wrapper = address(new TaikoWrapper(taikoInbox, forcedInclusionStore, router));
        console2.log(
            "Upgrading wrapper calldata: ", abi.encodeCall(UUPSUpgradeable.upgradeTo, (wrapper))
        );

        address proverSetImpl = new ProverSet(rollupResolver, taikoInbox, taikoToken, router);
        console2.log(
            "Upgrading ProverSet calldata: ",
            abi.encodeCall(UUPSUpgradeable.upgradeTo, (proverSetImpl))
        );
        console2.log(
            "Register ProverSet template calldata: ",
            abi.encodeCall(
                DefaultResolver.registerAddress,
                (uint64(block.chainid), bytes32(bytes("prover_set")), proverSetImpl)
            )
        );
    }
}
