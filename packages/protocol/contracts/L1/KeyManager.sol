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

// TODO: implement this contract
contract KeyManager is OwnableUpgradeable {
    /*************
     * Variables *
     *************/

    mapping(bytes32 => bytes) keys;

    /*************
     * Events *
     *************/

    event KeySet(string indexed _name, bytes _newKey, bytes _oldKey);

    function init() external initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    function setKey(string calldata name, bytes calldata key)
        external
        onlyOwner
    {
        // TODO: implement and emit event
        _oldKey = keys[name];
        keys[name] = key;
        emit KeySet(name, key, _oldKey);
    }

    function getKey(string memory name) public view returns (bytes memory) {
        return keys[name];
    }
}
