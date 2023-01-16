// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../thirdparty/LibBytesUtils.sol";
import "hardhat/console.sol";

contract TestVerifier {
    using LibBytesUtils for bytes;

    event ProofData(bytes data);

    function verifyZKP(
        address prover,
        bytes memory zkproof
    ) external returns (bool verified) {
        // bytes memory sliced = zkproof.slice(64);
        // console.logBytes(zkproof);
        // console.logBytes(sliced);

        // emit ProofData(zkproof);

        (verified, ) = prover.staticcall(zkproof);

        console.logBool(verified);

        // assembly {
        //    let success := staticcall(gas(), prover, add(zkproof, 64), mload(zkproof), 0, 0)
        //    if eq(success, 1) {
        //         verified := true
        //    }
        // }
    }
}
