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
        uint64 numPendingBlocks,
        uint64 numUnprovenBlocks,
        address proposer,
        uint128 gasLimit
    ) external returns (uint128 askPrice);

    function payProver(
        uint256 blockId,
        uint256 uncleId,
        address prover,
        uint128 askPrice,
        uint128 gasLimit,
        uint64 proposedAt,
        uint64 provenAt
    ) external;

    function gasLimitBase() external view returns (uint128);

    function getGasPrice() external view returns (uint128 askPrice);

    function feeToken() external view returns (address);

    function estimateGasFee(uint128 gasLimit) external view returns (uint128);
}
