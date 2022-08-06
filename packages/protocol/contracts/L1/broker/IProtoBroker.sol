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
        uint64 numUnprovenBlocks,
        address proposer,
        uint128 gasLimit
    ) external returns (uint128 gasFeeReceived);

    function payProver(
        uint256 blockId,
        uint256 uncleId,
        address prover,
        uint128 gasFeeReceived,
        uint64 proposedAt,
        uint64 provenAt
    ) external returns (uint128 gasFeePaid);

    function feeToken() external view returns (address);

    function estimateGasFee(uint128 gasLimit, uint64 numUnprovenBlocks)
        external
        view
        returns (uint128 gasFee);
}
