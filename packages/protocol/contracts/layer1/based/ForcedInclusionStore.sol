// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibMath.sol";
import "./IForcedInclusionStore.sol";
import "src/shared/libs/LibStrings.sol";

/// @title ForcedInclusionStore
/// @custom:security-contact
contract ForcedInclusionStore is EssentialContract, IForcedInclusionStore {
    using LibMath for uint256;

    uint256 public inclusionWindow;

    uint256 public basePriorityFee;

    uint64 public head;
    uint64 public tail;

    mapping(uint256 id => ForcedInclusion inclusion) public forcedInclusionQueue;

    uint256[44] private __gap;

    constructor(address _resolver, uint256 _inclusionWindow, uint256 _basePriorityFee) EssentialContract(_resolver) { 
        require(_inclusionWindow > 0, "inclusionWindow must be greater than 0");
        require(_basePriorityFee > 0, "basePriorityFee must be greater than 0");
        
        inclusionWindow = _inclusionWindow;
        basePriorityFee = _basePriorityFee;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function updateBasePriorityFee(uint256 _newBasePriorityFee) external onlyOwner {
        basePriorityFee = _newBasePriorityFee;
    }

    function getRequiredPriorityFee() public view returns (uint256) {
        uint256 queueLength = tail - head;
        if (queueLength == 0) {
            return basePriorityFee;
        }

        return (2 ** queueLength).max(4096) * basePriorityFee;
    }
    function storeForcedInclusion(bytes32 blobHash, uint32 blobByteOffset, uint32 blobByteSize) payable external {
        uint256 requiredPriorityFee = getRequiredPriorityFee();
        require(msg.value == requiredPriorityFee, ForcedInclusionInsufficientPriorityFee());

        uint64 id = tail + 1;
        ForcedInclusion memory forcedInclusion = ForcedInclusion({
            blobHash: blobHash,
            blobByteOffset: blobByteOffset,
            blobByteSize: blobByteSize,
            timestamp: block.timestamp,
            priorityFee: msg.value,
            id: id,
            processed: false
        });

        forcedInclusionQueue[tail] = forcedInclusion;

        tail++;

        emit ForcedInclusionStored(forcedInclusion);
    }

     function consumeForcedInclusion() external override returns (ForcedInclusion memory) {
        address operator = resolve(LibStrings.B_TAIKO_FORCED_INCLUSION_INBOX, false);
        require(msg.sender == operator, NotTaikoForcedInclusionInbox());

        ForcedInclusion memory forcedInclusion;
        if (head == tail) {
            return forcedInclusion;
        }
        
        // we only need to check the first one, since it will be the oldest.
        ForcedInclusion storage inclusion = forcedInclusionQueue[head];
        if (inclusion.timestamp + inclusionWindow < block.timestamp) {
            inclusion.processed = true;
            ForcedInclusion memory consumedInclusion = forcedInclusionQueue[head];
            head++;

            emit ForcedInclusionConsumed(consumedInclusion);
            
            return consumedInclusion;
        }

        return forcedInclusion;
     }
}