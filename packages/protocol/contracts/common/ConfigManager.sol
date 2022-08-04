// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ConfigManager is OwnableUpgradeable {
    /*************
     * Variables *
     *************/

    mapping(bytes32 => bytes) private keys;

    /*************
     * Events *
     *************/

    event KeySet(string indexed _name, bytes _newKey, bytes _oldKey);

    function init() external initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    function set(string calldata name, bytes calldata key) external onlyOwner {
        bytes32 _nameHash = keccak256(abi.encodePacked(name));
        bytes memory _oldKey = keys[_nameHash];
        keys[_nameHash] = key;
        emit KeySet(name, key, _oldKey);
    }

    function get(string memory name) public view returns (bytes memory) {
        return keys[keccak256(abi.encodePacked(name))];
    }
}
