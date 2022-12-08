// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/AddressResolver.sol";
import "../TkoToken.sol";
import "./V1Utils.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Verifying {
    using SafeCastUpgradeable for uint256;
    event BlockVerified(uint256 indexed id, bytes32 blockHash);

    event HeaderSynced(
        uint256 indexed height,
        uint256 indexed srcHeight,
        bytes32 srcHash
    );

    function init(
        LibData.State storage state,
        bytes32 genesisBlockHash
    ) public {
        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = uint64(block.timestamp);
        state.nextBlockId = 1;
        state.lastProposedAt = uint64(block.timestamp);
        state.l2Hashes[0] = genesisBlockHash;

        emit BlockVerified(0, genesisBlockHash);
        emit HeaderSynced(block.number, 0, genesisBlockHash);
    }

    function verifyBlocks(
        LibData.State storage state,
        AddressResolver resolver,
        uint256 maxBlocks,
        bool checkHalt
    ) public {
        bool halted = V1Utils.isHalted(state);
        if (checkHalt) {
            require(!halted, "L1:halted");
        } else if (halted) {
            // skip finalizing blocks
            return;
        }

        uint64 latestL2Height = state.latestVerifiedHeight;
        bytes32 latestL2Hash = state.l2Hashes[latestL2Height];
        uint64 processed = 0;

        for (
            uint256 i = state.latestVerifiedId + 1;
            i < state.nextBlockId && processed <= maxBlocks;
            i++
        ) {
            LibData.ForkChoice storage fc = state.forkChoices[i][latestL2Hash];
            LibData.ProposedBlock storage target = LibData.getProposedBlock(
                state,
                i
            );

            // Uncle proof can not take more than 2x time the first proof did.
            if (!_isVerifiable(state, fc)) {
                break;
            } else {
                if (fc.blockHash != LibConstants.K_BLOCK_DEADEND_HASH) {
                    latestL2Height += 1;
                    latestL2Hash = fc.blockHash;
                }

                state.avgProofTime = V1Utils
                    .movingAverage({
                        maValue: state.avgProofTime,
                        newValue: fc.provenAt - target.proposedAt,
                        maf: LibConstants.K_PROOF_TIME_MAF
                    })
                    .toUint64();

                processed += 1;
                emit BlockVerified(i, fc.blockHash);
                _cleanUp(fc);
            }
        }

        if (processed > 0) {
            state.latestVerifiedId += processed;

            if (latestL2Height > state.latestVerifiedHeight) {
                state.latestVerifiedHeight = latestL2Height;
                state.l2Hashes[latestL2Height] = latestL2Hash;
                emit HeaderSynced(block.number, latestL2Height, latestL2Hash);
            }
        }
    }

    function _cleanUp(LibData.ForkChoice storage fc) private {
        fc.blockHash = 0;
        fc.provenAt = 0;
        for (uint i = 0; i < fc.provers.length; i++) {
            fc.provers[i] = address(0);
        }
        delete fc.provers;
    }

    function _isVerifiable(
        LibData.State storage state,
        LibData.ForkChoice storage fc
    ) private view returns (bool) {
        return
            fc.blockHash != 0 &&
            block.timestamp > V1Utils.uncleProofDeadline(state, fc);
    }
}
