// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../TaikoData.sol";

/// @author dantaik <dan@taiko.xyz>
library LibHeaderSyncing {
    function getL2BlockHash(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 number
    ) public view returns (bytes32) {
        require(
            number <= state.latestVerifiedHeight &&
                number + config.blockHashHistory > state.latestVerifiedHeight,
            "L1:number"
        );
        return getL2Hash(state, config, number);
    }

    function setL2Hash(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 blockHeight,
        bytes32 blockHash
    ) internal {
        bytes32 k = _l2HashSlot(
            state.revertCount,
            config.blockHashHistory,
            blockHeight
        );
        assembly {
            sstore(k, blockHash)
        }
    }

    function getL2Hash(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 blockHeight
    ) internal view returns (bytes32 hash) {
        bytes32 k = _l2HashSlot(
            state.revertCount,
            config.blockHashHistory,
            blockHeight
        );
        assembly {
            hash := sload(k)
        }
    }

    function _l2HashSlot(
        uint64 revertCount,
        uint256 blockHashHistory,
        uint256 blockHeight
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "L2Hash",
                    revertCount,
                    blockHeight % blockHashHistory
                )
            );
    }
}
