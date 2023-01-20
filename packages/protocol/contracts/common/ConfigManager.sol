// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ConfigManager is OwnableUpgradeable {
    mapping(bytes32 => bytes) private kv;

    event Updated(string indexed name, bytes newVal, bytes oldVal);

    function init() external initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    function setValue(
        string calldata name,
        bytes calldata val
    ) external onlyOwner {
        bytes32 k = keccak256(abi.encodePacked(name));
        bytes memory oldVal = kv[k];
        if (keccak256(oldVal) != keccak256(val)) {
            kv[k] = val;
            emit Updated(name, val, oldVal);
        }
    }

    function getValue(string memory name) public view returns (bytes memory) {
        return kv[keccak256(abi.encodePacked(name))];
    }
}
