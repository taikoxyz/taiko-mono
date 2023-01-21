// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

/* Library Imports */
import {LibMerkleTrie} from "../../thirdparty/LibMerkleTrie.sol";

/**
 * @title TestLibMerkleTrie
 */
contract TestLibMerkleTrie {
    function verifyInclusionProof(
        bytes memory _key,
        bytes memory _value,
        bytes memory _proof,
        bytes32 _root
    ) public pure returns (bool) {
        return LibMerkleTrie.verifyInclusionProof(_key, _value, _proof, _root);
    }

    function get(
        bytes memory _key,
        bytes memory _proof,
        bytes32 _root
    ) public pure returns (bool, bytes memory) {
        return LibMerkleTrie.get(_key, _proof, _root);
    }
}
