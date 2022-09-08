// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../../common/ConfigManager.sol";
import "../../libs/LibConstants.sol";
import "../../libs/LibTxDecoder.sol";
import "../LibData.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Proposing {
    using LibTxDecoder for bytes;
    using SafeCastUpgradeable for uint256;
    using LibData for LibData.State;

    event BlockCommitted(bytes32 hash, uint256 validSince);
    event BlockProposed(uint256 indexed id, LibData.BlockContext context);

    function commitBlock(LibData.State storage s, bytes32 commitHash) public {
        require(commitHash != 0, "L1:hash");
        require(s.commits[commitHash] == 0, "L1:committed");
        s.commits[commitHash] = block.number;

        emit BlockCommitted(
            commitHash,
            block.number + LibConstants.TAIKO_COMMIT_DELAY_CONFIRMATIONS
        );
    }

    function proposeBlock(LibData.State storage s, bytes[] calldata inputs)
        public
    {
        require(inputs.length == 2, "L1:inputs:size");
        LibData.BlockContext memory context = abi.decode(
            inputs[0],
            (LibData.BlockContext)
        );
        bytes calldata txList = inputs[1];

        _validateContext(context);

        bytes32 commitHash = _calculateCommitHash(
            context.beneficiary,
            context.txListHash
        );

        require(isCommitValid(s, commitHash), "L1:commit");
        delete s.commits[commitHash];

        require(
            txList.length > 0 &&
                txList.length <= LibConstants.TAIKO_BLOCK_MAX_TXLIST_BYTES &&
                context.txListHash == txList.hashTxList(),
            "L1:txList"
        );
        require(
            s.nextPendingId <=
                s.lastFinalizedId + LibConstants.TAIKO_MAX_PENDING_BLOCKS,
            "L1:tooMany"
        );

        context.id = s.nextPendingId;
        context.anchorHeight = block.number - 1;
        context.anchorHash = blockhash(block.number - 1);
        context.proposedAt = uint64(block.timestamp);

        // if multiple L2 blocks included in the same L1 block,
        // their block.mixHash fields for randomness will be the same.
        context.mixHash = bytes32(block.difficulty);

        uint256 proposerFee = 0;

        s.savePendingBlock(
            s.nextPendingId,
            LibData.PendingBlock({
                contextHash: LibData.hashContext(context),
                proposerFee: proposerFee.toUint128(),
                everProven: uint8(LibData.EverProven.NO)
            })
        );

        // numUnprovenBlocks += 1;

        emit BlockProposed(s.nextPendingId++, context);
    }

    function isCommitValid(LibData.State storage s, bytes32 hash)
        public
        view
        returns (bool)
    {
        return
            hash != 0 &&
            s.commits[hash] != 0 &&
            block.number >=
            s.commits[hash] + LibConstants.TAIKO_COMMIT_DELAY_CONFIRMATIONS;
    }

    function _validateContext(LibData.BlockContext memory context)
        private
        pure
    {
        require(
            context.id == 0 &&
                context.anchorHeight == 0 &&
                context.anchorHash == 0 &&
                context.mixHash == 0 &&
                context.proposedAt == 0 &&
                context.beneficiary != address(0) &&
                context.txListHash != 0,
            "L1:placeholder"
        );

        require(
            context.gasLimit <= LibConstants.TAIKO_BLOCK_MAX_GAS_LIMIT,
            "L1:gasLimit"
        );
        require(context.extraData.length <= 32, "L1:extraData");
    }

    function _calculateCommitHash(address beneficiary, bytes32 txListHash)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(beneficiary, txListHash));
    }
}
