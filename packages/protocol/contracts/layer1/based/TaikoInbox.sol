// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "src/shared/common/EssentialContract.sol";
import "./LibData.sol";
import "./LibProposing.sol";
import "./LibProving.sol";
import "./LibVerifying.sol";
import "./TaikoEvents.sol";
import "./ITaikoL1.sol";

/// @title TaikoInbox
/// @custom:security-contact security@taiko.xyz
contract TaikoInbox is EssentialContract {
	    // Ring buffer for proposed blocks and a some recent verified blocks.
        mapping(uint64 blockId_mod_blockRingBufferSize => TaikoData.BlockV2 blk) blocks;
        // Indexing to transition ids (ring buffer not possible)
        mapping(uint64 blockId => mapping(bytes32 parentHash => uint24 transitionId)) transitionIds;
        // Ring buffer for transitions
        mapping(
            uint64 blockId_mod_blockRingBufferSize
                => mapping(uint24 transitionId => TaikoData.TransitionState ts)
        ) transitions;
        bytes32 __reserve1; // Used as a ring buffer for Ether deposits
        TaikoData.SlotA slotA; // slot 5
        TaikoData.SlotB slotB; // slot 6
        mapping(address account => uint256 bond) bondBalance;
        uint256[43] __gap;
}