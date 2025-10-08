// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibNames.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "./IForcedInclusionStore.sol";

/// @title ForcedInclusionStore
/// @dev A contract for storing and managing forced inclusion requests. Forced inclusions allow
/// users to pay a fee to ensure their transactions are included in a block. The contract maintains
/// a FIFO queue of inclusion requests.
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact
contract ForcedInclusionStore is EssentialContract, IForcedInclusionStore {
    using LibAddress for address;
    using LibMath for uint256;

    uint8 public immutable inclusionDelay; // measured in the number of batches
    uint64 public immutable feeInGwei;
    ITaikoInbox public immutable inbox;
    address public immutable inboxWrapper;

    mapping(uint256 id => ForcedInclusion inclusion) public queue; // slot 1
    uint64 public head; // slot 2
    uint64 public tail;
    uint64 public lastProcessedAtBatchId;
    uint64 private __reserved1;

    uint256[48] private __gap;

    // keccak256(abi.encode(uint256(keccak256("taiko.alethia.forcedinclusion.storage.TransactionGuard"))
    // - 1) & ~bytes32(uint256(0xff));
    bytes32 private constant _TRANSACTION_GUARD =
        0x5a1e3a5f720a5155ea49503410bd539c2a6a2a71c3684875803b191fd01b8100;

    modifier onlyStandaloneTx() {
        bytes32 guard;
        assembly {
            guard := tload(_TRANSACTION_GUARD)
        }
        require(guard == 0, MultipleCallsInOneTx());
        assembly {
            tstore(_TRANSACTION_GUARD, 1)
        }
        _;
        // Will clean up at the end of the transaction
    }

    constructor(
        uint8 _inclusionDelay,
        uint64 _feeInGwei,
        address _inbox,
        address _inboxWrapper
    )
        nonZeroValue(_inclusionDelay)
        nonZeroValue(_feeInGwei)
        nonZeroAddr(_inbox)
        nonZeroAddr(_inboxWrapper)
    {
        inclusionDelay = _inclusionDelay;
        feeInGwei = _feeInGwei;
        inbox = ITaikoInbox(_inbox);
        inboxWrapper = _inboxWrapper;
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
        onlyStandaloneTx
        whenNotPaused
    {
        bytes32 blobHash = _blobHash(blobIndex);
        require(blobHash != bytes32(0), BlobNotFound());
        require(msg.value == feeInGwei * 1 gwei, IncorrectFee());

        ForcedInclusion memory inclusion = ForcedInclusion({
            blobHash: blobHash,
            feeInGwei: uint64(msg.value / 1 gwei),
            createdAtBatchId: _nextBatchId(),
            blobByteOffset: blobByteOffset,
            blobByteSize: blobByteSize,
            blobCreatedIn: uint64(block.number)
        });

        queue[tail++] = inclusion;

        emit ForcedInclusionStored(inclusion);
    }

    function consumeOldestForcedInclusion(address _feeRecipient)
        external
        onlyFrom(inboxWrapper)
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
        return inbox.v4GetStats2().numBatches;
    }
}
