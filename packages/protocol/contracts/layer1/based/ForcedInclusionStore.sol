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

    uint256[45] private __gap;

    constructor(address _resolver, uint256 _inclusionWindow, uint256 _basePriorityFee) EssentialContract(_resolver) { 
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
        if (forcedInclusions.length == 0) {
            return basePriorityFee;
        }
        return (2 ** forcedInclusions.length).max(4096) * basePriorityFee;
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

    /// @inheritdoc IForcedInclusionStore
    function consumeForcedInclusion() external override returns (ForcedInclusion memory) {
        address operator = resolve(LibStrings.B_TAIKO_FORCED_INCLUSION_INBOX, false);
        require(msg.sender == operator, NotTaikoForcedInclusionInbox());

        // get the first forced inclusion that is due to be included
        for (uint256 i = 0; i < forcedInclusions.length; i++) {
            ForcedInclusion storage inclusion = forcedInclusions[i];
            if (inclusion.timestamp + inclusionWindow <= block.timestamp) {
                ForcedInclusion memory consumedInclusion = inclusion;
                forcedInclusions[i] = forcedInclusions[forcedInclusions.length - 1];
                forcedInclusions.pop();

                emit ForcedInclusionConsumed(consumedInclusion);
                
                return consumedInclusion;
            }
        }

        // non found, return empty forcedInclusion struct
        ForcedInclusion memory forcedInclusion;
        return forcedInclusion;
    }

    function getForcedInclusions() external view returns (ForcedInclusion[] memory) {
        return forcedInclusions;
    }
}