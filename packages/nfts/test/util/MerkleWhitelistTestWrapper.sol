// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { MerkleWhitelist } from "../../contracts/taikoon/MerkleWhitelist.sol";

/// @custom:oz-upgrades-from MerkleWhitelist
contract MerkleWhitelistTestWrapper is MerkleWhitelist {
    /*
    function initialize(bytes32 _root) external {
        __MerkleWhitelist_init(_root);
    }*/

    function updateRoot(bytes32 _root) external {
        _updateRoot(_root);
    }

    function consumeMint(bytes32[] calldata _proof, uint256 _freeMints) external {
        _consumeMint(_proof, _freeMints);
    }
}
