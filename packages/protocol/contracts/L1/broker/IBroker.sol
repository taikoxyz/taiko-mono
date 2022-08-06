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
interface IBroker {
    function gasLimitBase() external view returns (uint256);

    function currentGasPrice() external view returns (uint256);

    function feeToken() external view returns (address);

    function estimateFee(uint256 gasLimit) external view returns (uint256);

    function chargeProposer(
        uint256 blockId,
        address proposer,
        uint256 gasLimit
    ) external;

    function payProver(
        uint256 blockId,
        address prover,
        uint256 gasPrice,
        uint256 gasLimit,
        uint256 provingDelay,
        uint256 uncleId
    ) external;
}
