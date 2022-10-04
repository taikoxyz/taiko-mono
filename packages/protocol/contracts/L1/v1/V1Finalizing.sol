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

import "../LibData.sol";
import "../TkoToken.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Finalizing {
    using SafeCastUpgradeable for uint256;

    event BlockFinalized(uint256 indexed id, bytes32 blockHash, uint256 fee);

    event HeaderSynced(
        uint256 indexed height,
        uint256 indexed srcHeight,
        bytes32 srcHash
    );

    function init(LibData.State storage s, bytes32 _genesisBlockHash) public {
        s.l2Hashes[0] = _genesisBlockHash;
        s.nextBlockId = 1;
        s.genesisHeight = uint64(block.number);
        s.lastBlockTime = uint64(block.timestamp);

        emit BlockFinalized(0, _genesisBlockHash, 0);
        emit HeaderSynced(block.number, 0, _genesisBlockHash);
    }

    function finalizeBlocks(
        LibData.State storage s,
        AddressResolver resolver,
        uint256 maxBlocks
    ) public {
        uint64 latestL2Height = s.latestFinalizedHeight;
        bytes32 latestL2Hash = s.l2Hashes[latestL2Height];
        uint64 processed = 0;
        address tkoToken;

        for (
            uint256 i = s.latestFinalizedId + 1;
            i < s.nextBlockId && processed <= maxBlocks;
            i++
        ) {
            LibData.ForkChoice storage fc = s.forkChoices[i][latestL2Hash];

            bytes32 _blockHash;

            if (
                fc.blockHash == LibConstants.TAIKO_BLOCK_DEADEND_HASH
            ) {} else if (fc.blockHash != 0) {
                latestL2Height += 1;
                latestL2Hash = fc.blockHash;
                _blockHash = latestL2Hash;
            } else {
                break;
            }

            processed += 1;

            if (tkoToken == address(0)) {
                tkoToken = resolver.resolve("tko_token");
            }

            uint256 weight = 3628800; // a number that can be devided by 1,...,10.
            uint256 totalWeight;
            uint256 count = fc.provers.length;
            for (uint256 j = 0; j < count; j++) {
                totalWeight += weight / (j + 1);
            }

            uint128 fee = getProvingFee(s, fc.provenAt - fc.proposedAt);
            // The reward ratio is: 1/1, 1/2, 1/3, ..., 1/n.
            for (uint256 j = 0; j < count; j++) {
                TkoToken(tkoToken).mint(
                    fc.provers[j],
                    (fee * weight) / totalWeight / (j + 1)
                );
            }
            s.maProvingFee = LibData
                .calcMovingAvg(s.maProvingFee, fee, 64)
                .toUint128();

            s.maProvingDelay = LibData
                .calcMovingAvg(
                    s.maProvingDelay,
                    fc.provenAt - fc.proposedAt,
                    64
                )
                .toUint64();

            emit BlockFinalized(i, _blockHash, fee);
        }

        if (processed > 0) {
            s.latestFinalizedId += processed;

            if (latestL2Height > s.latestFinalizedHeight) {
                s.latestFinalizedHeight = latestL2Height;
                s.l2Hashes[latestL2Height] = latestL2Hash;
                emit HeaderSynced(block.number, latestL2Height, latestL2Hash);
            }
        }
    }

    function getProvingFee(LibData.State storage s, uint256 provingDelay)
        internal
        view
        returns (uint128)
    {}
}
