// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

/* Library Imports */
import {LibSecureMerkleTrie} from "../../thirdparty/LibSecureMerkleTrie.sol";

/**
 * @title TestLibSecureMerkleTrie
 */
contract TestLibSecureMerkleTrie {
    function verifyInclusionProof(
        bytes memory _key,
        bytes memory _value,
        bytes memory _proof,
        bytes32 _root
    ) public pure returns (bool) {
        return
            LibSecureMerkleTrie.verifyInclusionProof(
                _key,
                _value,
                _proof,
                _root
            );
    }

    function get(
        bytes memory _key,
        bytes memory _proof,
        bytes32 _root
    ) public pure returns (bool, bytes memory) {
        return LibSecureMerkleTrie.get(_key, _proof, _root);
    }
}
