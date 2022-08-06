// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

/// @author dantaik <dan@taiko.xyz>
interface IProtoBroker {
    function chargeProposer(
        uint256 blockId,
        address proposer,
        uint128 gasLimit,
        uint64 numUnprovenBlocks
    ) external returns (uint128 gasFeeReceived);

    function payProver(
        uint256 blockId,
        address prover,
        uint256 uncleId,
        uint64 proposedAt,
        uint64 provenAt,
        uint128 gasFeeReceived
    ) external returns (uint128 gasFeePaid);

    function getProposerFee(uint128 gasLimit, uint64 numUnprovenBlocks)
        external
        view
        returns (uint128 gasFee);
}
