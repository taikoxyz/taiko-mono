// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../thirdparty/Lib_RLPWriter.sol";
import "../thirdparty/Lib_MerkleTrie.sol";

/// @author dantaik <dan@taiko.xyz>
library LibMerkleProof {
    function prove(
        bytes32 root,
        uint256 index,
        bytes memory value,
        bytes calldata mkproof
    ) public pure {
        bool verified = Lib_MerkleTrie.verifyInclusionProof(
            Lib_RLPWriter.writeUint(index),
            value,
            mkproof,
            root
        );

        require(verified, "LTP:invalid footprint proof");
    }
}
