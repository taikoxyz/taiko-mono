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
    event BlockProposed(uint256 indexed id, LibData.BlockMetadata meta);

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
        LibData.BlockMetadata memory meta = abi.decode(
            inputs[0],
            (LibData.BlockMetadata)
        );
        bytes calldata txList = inputs[1];

        _validateMetadata(meta);

        bytes32 commitHash = _calculateCommitHash(
            meta.beneficiary,
            meta.txListHash
        );

        require(isCommitValid(s, commitHash), "L1:commit");
        delete s.commits[commitHash];

        require(
            txList.length > 0 &&
                txList.length <= LibConstants.TAIKO_TXLIST_MAX_BYTES &&
                meta.txListHash == txList.hashTxList(),
            "L1:txList"
        );
        require(
            s.nextBlockId <=
                s.latestFinalizedId + LibConstants.TAIKO_MAX_PROPOSED_BLOCKS,
            "L1:tooMany"
        );

        meta.id = s.nextBlockId;
        meta.l1Height = block.number - 1;
        meta.l1Hash = blockhash(block.number - 1);

        // Taiko client requires parent.timestamp >= block.timestamp, which
        // is different from the Ethereum specification.
        meta.timestamp = uint64(block.timestamp);

        // if multiple L2 blocks included in the same L1 block,
        // their block.mixHash fields for randomness will be the same.
        meta.mixHash = bytes32(block.difficulty);

        uint256 proposerFee = 0;

        s.saveProposedBlock(
            s.nextBlockId,
            LibData.ProposedBlock({
                metaHash: LibData.hashMetadata(meta),
                proposerFee: proposerFee.toUint128(),
                everProven: uint8(LibData.EverProven.NO)
            })
        );

        // numUnprovenBlocks += 1;

        emit BlockProposed(s.nextBlockId++, meta);
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

    function _validateMetadata(LibData.BlockMetadata memory meta) private pure {
        require(
            meta.id == 0 &&
                meta.l1Height == 0 &&
                meta.l1Hash == 0 &&
                meta.mixHash == 0 &&
                meta.timestamp == 0 &&
                meta.beneficiary != address(0) &&
                meta.txListHash != 0,
            "L1:placeholder"
        );

        require(
            meta.gasLimit <= LibConstants.TAIKO_BLOCK_MAX_GAS_LIMIT,
            "L1:gasLimit"
        );
        require(meta.extraData.length <= 32, "L1:extraData");
    }

    function _calculateCommitHash(address beneficiary, bytes32 txListHash)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(beneficiary, txListHash));
    }
}
