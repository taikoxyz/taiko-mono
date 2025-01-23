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

    ForcedInclusion[] forcedInclusions;

    uint64 forcedInclusionId;

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
      return basePriorityFee;
    }
    
    function storeForcedInclusion(bytes32 blobHash, uint32 blobByteOffset, uint32 blobByteSize) payable external {
        uint256 requiredPriorityFee = getRequiredPriorityFee();
        require(msg.value == requiredPriorityFee, ForcedInclusionInsufficientPriorityFee());

        ForcedInclusion memory forcedInclusion = ForcedInclusion({
            blobHash: blobHash,
            blobByteOffset: blobByteOffset,
            blobByteSize: blobByteSize,
            timestamp: block.timestamp,
            priorityFee: msg.value,
            id: ++forcedInclusionId
        });

        forcedInclusions.push(forcedInclusion);

        emit ForcedInclusionStored(forcedInclusion);
    }

     function consumeForcedInclusion() external override returns (ForcedInclusion memory) {
        if (forcedInclusions.length == 0) {
            revert ForcedInclusionHashNotFound();
        }

        // we only need to check the first one, since it will be the oldest.
        ForcedInclusion storage inclusion = forcedInclusions[0];
        if (inclusion.timestamp + inclusionWindow <= block.timestamp) {
            ForcedInclusion memory consumedInclusion = inclusion;
            forcedInclusions.pop();

            emit ForcedInclusionConsumed(consumedInclusion);
            
            return consumedInclusion;
        }

        
        // non found, return empty forcedInclusion struct
        ForcedInclusion memory forcedInclusion;
        return forcedInclusion;
    }

    function getForcedInclusions() external view returns (ForcedInclusion[] memory) {
        return forcedInclusions;
    }
}