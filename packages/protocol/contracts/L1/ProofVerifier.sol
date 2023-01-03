// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../thirdparty/LibMerkleTrie.sol";
import "../libs/LibZKP.sol";

/// @author dantaik <dan@taiko.xyz>
interface IProofVerifier {
    function verifyZKP(
        bytes memory verificationKey,
        bytes calldata zkproof,
        bytes32 blockHash,
        address prover,
        bytes32 txListHash
    ) external pure returns (bool verified);

    function verifyMKP(
        bytes memory key,
        bytes memory value,
        bytes memory proof,
        bytes32 root
    ) external pure returns (bool verified);
}

/// @author dantaik <dan@taiko.xyz>
contract ProofVerifier is IProofVerifier {
    function verifyZKP(
        bytes memory verificationKey,
        bytes calldata zkproof,
        bytes32 blockHash,
        address prover,
        bytes32 txListHash
    ) external pure returns (bool) {
        return
            LibZKP.verify({
                verificationKey: verificationKey,
                zkproof: zkproof,
                blockHash: blockHash,
                prover: prover,
                txListHash: txListHash
            });
    }

    function verifyMKP(
        bytes memory key,
        bytes memory value,
        bytes memory proof,
        bytes32 root
    ) external pure returns (bool) {
        return
            LibMerkleTrie.verifyInclusionProof({
                _key: key,
                _value: value,
                _proof: proof,
                _root: root
            });
    }
}
