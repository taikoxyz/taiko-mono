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
        uint256 gasLimit,
        uint256 numUnprovenBlocks
    ) external returns (uint256 proposerFee);

    function payProvers(
        uint256 blockId,
        uint256 proposedAt,
        uint256 provenAt,
        uint256 proposerFee,
        address[] memory provers
    ) external returns (uint256 totalProverFees);

    function payFee(address recipient, uint256 amount)
        external
        returns (bool success);

    function getProposerFee(uint256 gasLimit, uint256 numUnprovenBlocks)
        external
        view
        returns (uint256 gasFee);
}
