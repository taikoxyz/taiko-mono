// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../../test/shared/DeployCapability.sol";
import "../../contracts/layer1/hekla/HeklaTaikoL1.sol";
import "../../contracts/shared/bridge/Bridge.sol";
import "../../contracts/shared/common/AddressManager.sol";
import "../../contracts/layer1/provers/ProverSet.sol";
import "../../contracts/layer1/provers/GuardianProver.sol";

contract UpgradeHeklaOntakeL1 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // TaikoL1
        UUPSUpgradeable(0x79C9109b764609df928d16fC4a91e9081F7e87DB).upgradeTo(
            address(new HeklaTaikoL1())
        );
        // Bridge
        UUPSUpgradeable(0xA098b76a3Dd499D3F6D58D8AcCaFC8efBFd06807).upgradeTo(address(new Bridge()));
        // Rollup address manager
        UUPSUpgradeable(0x1F027871F286Cf4B7F898B21298E7B3e090a8403).upgradeTo(
            address(new AddressManager())
        );
        // Shared address manager
        UUPSUpgradeable(0x7D3338FD5e654CAC5B10028088624CA1D64e74f7).upgradeTo(
            address(new AddressManager())
        );
        // Prover set
        UUPSUpgradeable(0xD3f681bD6B49887A48cC9C9953720903967E9DC0).upgradeTo(
            address(new ProverSet())
        );
        UUPSUpgradeable(0x335103c4fa2F55451975082136F1478eCFeB84B9).upgradeTo(
            address(new ProverSet())
        );
        // Guardian Prover
        UUPSUpgradeable(0x92F195a8702da2104aE8E3E10779176E7C35d6BC).upgradeTo(
            address(new GuardianProver())
        );
        UUPSUpgradeable(0x31d4d27da5c299d4b6CE19c869B8891C0002795d).upgradeTo(
            address(new GuardianProver())
        );
    }
}
