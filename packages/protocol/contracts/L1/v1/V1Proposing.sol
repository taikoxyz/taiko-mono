// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/ConfigManager.sol";
import "../../libs/LibConstants.sol";
import "../../libs/LibTxDecoder.sol";
import "../TkoToken.sol";
import "./V1Utils.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Proposing {
    using LibTxDecoder for bytes;
    using SafeCastUpgradeable for uint256;
    using LibData for LibData.State;

    event BlockCommitted(bytes32 hash, uint256 validSince);
    event BlockProposed(uint256 indexed id, LibData.BlockMetadata meta);

    function commitBlock(LibData.State storage s, bytes32 commitHash) public {
        // It's OK to allow committing block when the system is halt.
        // By not checking the halt status, this method will be cheaper.
        //
        // require(!V1Utils.isHalted(s), "L1:halt");

        require(commitHash != 0, "L1:hash");
        require(s.commits[commitHash] == 0, "L1:committed");
        s.commits[commitHash] = block.number;

        emit BlockCommitted(
            commitHash,
            block.number + LibConstants.K_COMMIT_DELAY_CONFIRMS
        );
    }

    function proposeBlock(
        LibData.State storage s,
        AddressResolver resolver,
        bytes[] calldata inputs
    ) public {
        require(!V1Utils.isHalted(s), "L1:halt");

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
                txList.length <= LibConstants.K_TXLIST_MAX_BYTES &&
                meta.txListHash == txList.hashTxList(),
            "L1:txList"
        );
        require(
            s.nextBlockId < s.latestVerifiedId + LibConstants.K_MAX_NUM_BLOCKS,
            "L1:tooMany"
        );

        meta.id = s.nextBlockId;
        meta.l1Height = block.number - 1;
        meta.l1Hash = blockhash(block.number - 1);
        meta.timestamp = uint64(block.timestamp);

        // if multiple L2 blocks included in the same L1 block,
        // their block.mixHash fields for randomness will be the same.
        meta.mixHash = bytes32(block.difficulty);

        s.saveProposedBlock(
            s.nextBlockId,
            LibData.ProposedBlock({
                metaHash: LibData.hashMetadata(meta),
                proposer: msg.sender,
                gasLimit: meta.gasLimit
            })
        );

        if (LibConstants.K_TOKENOMICS_ENABLED) {
            uint64 blockTime = meta.timestamp - s.lastProposedAt;
            (uint256 fee, uint256 premiumFee) = getBlockFee(s);
            s.feeBase = V1Utils.movingAverage(s.feeBase, fee, 1024);

            s.avgBlockTime = V1Utils
                .movingAverage(s.avgBlockTime, blockTime, 1024)
                .toUint64();

            // s.avgGasLimit = V1Utils
            //     .movingAverage(s.avgGasLimit, meta.gasLimit, 1024)
            //     .toUint64();

            TkoToken(resolver.resolve("tko_token")).burn(
                msg.sender,
                premiumFee
            );
        }

        s.lastProposedAt = meta.timestamp;
        emit BlockProposed(s.nextBlockId++, meta);
    }

    function getBlockFee(
        LibData.State storage s
    ) public view returns (uint256 fee, uint256 premiumFee) {
        fee = V1Utils.getTimeAdjustedFee(
            s,
            true,
            uint64(block.timestamp),
            s.lastProposedAt,
            s.avgBlockTime,
            LibConstants.K_BLOCK_TIME_CAP
        );
        premiumFee = V1Utils.getSlotsAdjustedFee(s, true, fee);
        premiumFee = V1Utils.getBootstrapDiscountedFee(s, premiumFee);
    }

    function isCommitValid(
        LibData.State storage s,
        bytes32 hash
    ) public view returns (bool) {
        return
            hash != 0 &&
            s.commits[hash] != 0 &&
            block.number >=
            s.commits[hash] + LibConstants.K_COMMIT_DELAY_CONFIRMS;
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
            meta.gasLimit <= LibConstants.K_BLOCK_MAX_GAS_LIMIT,
            "L1:gasLimit"
        );
        require(meta.extraData.length <= 32, "L1:extraData");
    }

    function _calculateCommitHash(
        address beneficiary,
        bytes32 txListHash
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(beneficiary, txListHash));
    }
}
