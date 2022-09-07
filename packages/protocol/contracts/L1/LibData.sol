// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

/**
 * @author dantaik <dan@taiko.xyz>
 * @notice This library offers two functions for EIP-1559-style math.
 *      See more at https://dankradfeist.de/ethereum/2022/03/16/exponential-eip1559.html
 */

// import "../common/ConfigManager.sol";
// import "../L2/TaikoL2.sol";
// import "../libs/LibBlockHeader.sol";
import "../libs/LibConstants.sol";

// import "../libs/LibTxDecoder.sol";
// import "../libs/LibReceiptDecoder.sol";
// import "../libs/LibZKP.sol";
// import "../thirdparty/Lib_BytesUtils.sol";
// import "../thirdparty/Lib_MerkleTrie.sol";
// import "../thirdparty/Lib_RLPWriter.sol";
library LibData {
    enum EverProven {
        _NO, //=0
        NO, //=1
        YES //=2
    }

    struct BlockContext {
        uint256 id;
        uint256 anchorHeight;
        bytes32 anchorHash;
        address beneficiary;
        uint64 gasLimit;
        uint64 proposedAt;
        bytes32 txListHash;
        bytes32 mixHash;
        bytes extraData;
    }

    struct PendingBlock {
        bytes32 contextHash;
        uint128 proposerFee;
        uint8 everProven;
    }

    struct ForkChoice {
        bytes32 blockHash;
        uint64 proposedAt;
        uint64 provenAt;
        address[] provers;
    }

    struct State {
        // block id => block hash
        mapping(uint256 => bytes32) finalizedBlocks;
        // block id => PendingBlock
        mapping(uint256 => PendingBlock) pendingBlocks;
        // block id => parent hash => fork choice
        mapping(uint256 => mapping(bytes32 => ForkChoice)) forkChoices;
        mapping(bytes32 => uint256) commits;
        uint64 genesisHeight;
        uint64 lastFinalizedHeight;
        uint64 lastFinalizedId;
        uint64 nextPendingId;
        uint64 numUnprovenBlocks;
    }

    function savePendingBlock(
        LibData.State storage s,
        uint256 id,
        PendingBlock memory blk
    ) internal {
        s.pendingBlocks[id % LibConstants.TAIKO_MAX_PENDING_BLOCKS] = blk;
    }

    function getPendingBlock(State storage s, uint256 id)
        internal
        view
        returns (PendingBlock storage)
    {
        return s.pendingBlocks[id % LibConstants.TAIKO_MAX_PENDING_BLOCKS];
    }

    function getFinalizedBlockHash(State storage s, uint256 id)
        internal
        view
        returns (bytes32)
    {
        require(id <= s.lastFinalizedId, "L1:id");
        return s.finalizedBlocks[id];
    }

    function getStateVariables(State storage s)
        internal
        view
        returns (
            uint64 genesisHeight,
            uint64 lastFinalizedHeight,
            uint64 lastFinalizedId,
            uint64 nextPendingId,
            uint64 numUnprovenBlocks
        )
    {
        genesisHeight = s.genesisHeight;
        lastFinalizedHeight = s.lastFinalizedHeight;
        lastFinalizedId = s.lastFinalizedId;
        nextPendingId = s.nextPendingId;
        numUnprovenBlocks = s.numUnprovenBlocks;
    }

    function hashContext(BlockContext memory context)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(context));
    }
}
