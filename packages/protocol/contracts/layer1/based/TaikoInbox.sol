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

/// @title TaikoL1
/// @notice This contract serves as the "base layer contract" of the Taiko protocol, providing
/// functionalities for proposing, proving, and verifying blocks. The term "base layer contract"
/// means that although this is usually deployed on L1, it can also be deployed on L2s to create
/// L3s. The contract also handles the deposit and withdrawal of Taiko tokens and Ether.
/// Additionally, this contract doesn't hold any Ether. Ether deposited to L2 are held by the Bridge
/// contract.
/// @dev Labeled in AddressResolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract TaikoL1 is EssentialContract {
	    // Ring buffer for proposed blocks and a some recent verified blocks.
        mapping(uint64 blockId_mod_blockRingBufferSize => BlockV2 blk) blocks;
        // Indexing to transition ids (ring buffer not possible)
        mapping(uint64 blockId => mapping(bytes32 parentHash => uint24 transitionId)) transitionIds;
        // Ring buffer for transitions
        mapping(
            uint64 blockId_mod_blockRingBufferSize
                => mapping(uint24 transitionId => TransitionState ts)
        ) transitions;
        bytes32 __reserve1; // Used as a ring buffer for Ether deposits
        SlotA slotA; // slot 5
        SlotB slotB; // slot 6
        mapping(address account => uint256 bond) bondBalance;
        uint256[43] __gap;
}