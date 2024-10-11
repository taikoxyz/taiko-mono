// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/interfaces/taiko/ITaikoL1.sol";

contract MockTaikoL1 is ITaikoL1 {
    bytes public params;
    bytes public txList;
    uint256 public blockId;
    Block public blk;

    function proposeBlock(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        payable
        returns (BlockMetadata memory a, EthDeposit[] memory b)
    {
        params = _params;
        txList = _txList;

        return (a, b);
    }

    function getStateVariables() external view returns (SlotA memory a, SlotB memory b) {
        b.numBlocks = uint64(blockId);
        return (a, b);
    }

    function getBlock(uint64) external view returns (Block memory blk_) {
        return blk;
    }

    /// @dev Force set for testing
    function setBlockId(uint256 id) external {
        blockId = id;
    }

    /// @dev Force set for testing
    function setBlock(bytes32 metahash, uint256 proposedAt) external {
        blk.metaHash = metahash;
        blk.proposedAt = uint64(proposedAt);
    }
}
