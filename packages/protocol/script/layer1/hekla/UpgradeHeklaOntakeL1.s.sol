// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "src/layer1/hekla/HeklaTaikoL1.sol";
import "src/shared/bridge/Bridge.sol";
import "src/layer1/provers/ProverSet.sol";
import "script/BaseScript.sol";

contract UpgradeHeklaOntakeL1 is BaseScript {
    function run() external broadcast {
        // Taiko
        UUPSUpgradeable(0x79C9109b764609df928d16fC4a91e9081F7e87DB).upgradeTo(
            address(new HeklaTaikoL1())
        );
        // Bridge
        UUPSUpgradeable(0xA098b76a3Dd499D3F6D58D8AcCaFC8efBFd06807).upgradeTo(address(new Bridge()));
        // Rollup address manager
        UUPSUpgradeable(0x1F027871F286Cf4B7F898B21298E7B3e090a8403).upgradeTo(
            address(new DefaultResolver())
        );
        // Shared address manager
        UUPSUpgradeable(0x7D3338FD5e654CAC5B10028088624CA1D64e74f7).upgradeTo(
            address(new DefaultResolver())
        );
        // Prover set
        UUPSUpgradeable(0xD3f681bD6B49887A48cC9C9953720903967E9DC0).upgradeTo(
            address(new ProverSet())
        );
        UUPSUpgradeable(0x335103c4fa2F55451975082136F1478eCFeB84B9).upgradeTo(
            address(new ProverSet())
        );
    }
}
