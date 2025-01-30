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
/// users to pay a  fee
///      to ensure their transactions are included in a block. The contract maintains a FIFO queue
/// of inclusion requests.
/// @custom:security-contact
contract ForcedInclusionStore is EssentialContract, IForcedInclusionStore {
    using LibAddress for address;
    using LibMath for uint256;

    uint256 private constant SECONDS_PER_BLOCK = 12;

    uint8 public immutable inclusionDelay;
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
        require(_inclusionDelay != 0 && _inclusionDelay % SECONDS_PER_BLOCK == 0, InvalidParams());
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

        ITaikoInbox inbox = ITaikoInbox(resolve(LibStrings.B_TAIKO, false));

        ForcedInclusion memory inclusion = ForcedInclusion({
            blobHash: blobHash,
            feeInGwei: uint64(msg.value / 1 gwei),
            createdAtBatchId: inbox.getStats2().numBatches,
            blobByteOffset: blobByteOffset,
            blobByteSize: blobByteSize
        });

        queue[tail++] = inclusion;

        emit ForcedInclusionStored(inclusion);
    }

    function consumeOldestForcedInclusion(address _feeRecipient)
        external
        nonReentrant
        onlyFromNamed(LibStrings.B_TAIKO_FORCED_INCLUSION_INBOX)
        returns (ForcedInclusion memory inclusion_)
    {
        // we only need to check the first one, since it will be the oldest.
        uint64 _head = head;
        ForcedInclusion storage inclusion = queue[_head];
        require(inclusion.createdAtBatchId != 0, NoForcedInclusionFound());

        ITaikoInbox inbox = ITaikoInbox(resolve(LibStrings.B_TAIKO, false));

        inclusion_ = inclusion;
        delete queue[_head];

        unchecked {
            lastProcessedAtBatchId = inbox.getStats2().numBatches;
            head = _head + 1;
        }

        emit ForcedInclusionConsumed(inclusion_);
        _feeRecipient.sendEtherAndVerify(inclusion_.feeInGwei * 1 gwei);
    }

    function getForcedInclusion(uint256 index) external view returns (ForcedInclusion memory) {
        return queue[index];
    }

    function getOldestForcedInclusionDeadline() public view returns (uint256) {
        unchecked {
            ForcedInclusion storage inclusion = queue[head];
            return inclusion.createdAtBatchId == 0
                ? type(uint64).max
                : uint256(lastProcessedAtBatchId).max(inclusion.createdAtBatchId) + inclusionDelay;
        }
    }

    function isOldestForcedInclusionDue() external view returns (bool) {
        ITaikoInbox inbox = ITaikoInbox(resolve(LibStrings.B_TAIKO, false));
        return inbox.getStats2().numBatches >= getOldestForcedInclusionDeadline();
    }

    // @dev Override this function for easier testing blobs
    function _blobHash(uint8 blobIndex) internal view virtual returns (bytes32) {
        return blobhash(blobIndex);
    }
}
