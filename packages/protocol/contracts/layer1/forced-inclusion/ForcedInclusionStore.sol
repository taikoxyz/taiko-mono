// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibStrings.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "./IForcedInclusionStore.sol";

/// @title ForcedInclusionStore
/// @dev A contract for storing and managing forced inclusion requests. Forced inclusions allow
/// users to pay a fee to ensure their transactions are included in a block. The contract maintains
/// a FIFO queue of inclusion requests.
/// @custom:security-contact
contract ForcedInclusionStore is EssentialContract, IForcedInclusionStore {
    using LibAddress for address;
    using LibMath for uint256;

    uint8 public immutable inclusionDelay; // measured in the number of batches
    uint64 public immutable feeInGwei;

    mapping(uint256 id => ForcedInclusion inclusion) public queue; // slot 1
    uint64 public head; // slot 2
    uint64 public tail;
    uint64 public lastProcessedAtBatchId;
    uint64 private __reserved1;

    uint256[48] private __gap;

    constructor(
        address _resolver,
        uint8 _inclusionDelay,
        uint64 _feeInGwei
    )
        EssentialContract(_resolver)
    {
        require(_inclusionDelay != 0, InvalidParams());
        require(_feeInGwei != 0, InvalidParams());

        inclusionDelay = _inclusionDelay;
        feeInGwei = _feeInGwei;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function storeForcedInclusion(
        uint8 blobIndex,
        uint32 blobByteOffset,
        uint32 blobByteSize
    )
        external
        payable
        nonReentrant
    {
        bytes32 blobHash = _blobHash(blobIndex);
        require(blobHash != bytes32(0), BlobNotFound());
        require(msg.value == feeInGwei * 1 gwei, IncorrectFee());

        ForcedInclusion memory inclusion = ForcedInclusion({
            blobHash: blobHash,
            feeInGwei: uint64(msg.value / 1 gwei),
            createdAtBatchId: _nextBatchId(),
            blobByteOffset: blobByteOffset,
            blobByteSize: blobByteSize
        });

        queue[tail++] = inclusion;

        emit ForcedInclusionStored(inclusion);
    }

    function consumeOldestForcedInclusion(address _feeRecipient)
        external
        onlyFromNamed(LibStrings.B_TAIKO_WRAPPER)
        nonReentrant
        returns (ForcedInclusion memory inclusion_)
    {
        // we only need to check the first one, since it will be the oldest.
        ForcedInclusion storage inclusion = queue[head];
        require(inclusion.createdAtBatchId != 0, NoForcedInclusionFound());

        inclusion_ = inclusion;

        lastProcessedAtBatchId = _nextBatchId();

        unchecked {
            delete queue[head++];
            _feeRecipient.sendEtherAndVerify(inclusion_.feeInGwei * 1 gwei);
        }
        emit ForcedInclusionConsumed(inclusion_);
    }

    function getForcedInclusion(uint256 index) external view returns (ForcedInclusion memory) {
        require(index >= head, InvalidIndex());
        require(index < tail, InvalidIndex());
        return queue[index];
    }

    function getOldestForcedInclusionDeadline() public view returns (uint256) {
        if (head == tail) return type(uint256).max;

        ForcedInclusion storage inclusion = queue[head];
        if (inclusion.createdAtBatchId == 0) return type(uint256).max;

        unchecked {
            return uint256(lastProcessedAtBatchId).max(inclusion.createdAtBatchId) + inclusionDelay;
        }
    }

    function isOldestForcedInclusionDue() external view returns (bool) {
        uint256 deadline = getOldestForcedInclusionDeadline();
        return deadline != type(uint256).max && _nextBatchId() >= deadline;
    }

    // @dev Override this function for easier testing blobs
    function _blobHash(uint8 blobIndex) internal view virtual returns (bytes32) {
        return blobhash(blobIndex);
    }

    function _nextBatchId() private view returns (uint64) {
        return ITaikoInbox(resolve(LibStrings.B_TAIKO, false)).getStats2().numBatches;
    }
}
