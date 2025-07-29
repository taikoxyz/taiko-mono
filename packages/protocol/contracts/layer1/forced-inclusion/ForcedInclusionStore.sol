// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibNames.sol";
import "./IForcedInclusionStore.sol";
import "src/layer1/based2/IInbox.sol";

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
    IInbox public immutable inbox;

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
        IInbox _inbox
    )
        nonZeroValue(_inclusionDelay)
        nonZeroValue(_feeInGwei)
        EssentialContract()
    {
        inclusionDelay = _inclusionDelay;
        feeInGwei = _feeInGwei;
        inbox = _inbox;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function storeForcedInclusion(
        uint8 blobIndex,
        uint32 blobByteOffset,
        uint32 blobByteSize,
        IInbox.Summary memory _summary
    )
        external
        payable
        onlyStandaloneTx
        whenNotPaused
    {
        bytes32 blobHash = _blobHash(blobIndex);
        require(blobHash != bytes32(0), BlobNotFound());
        require(msg.value == feeInGwei * 1 gwei, IncorrectFee());

        // Validate the summary to be able to use the next batch id
        inbox.validateSummary(_summary);

        ForcedInclusion memory inclusion = ForcedInclusion({
            blobHash: blobHash,
            feeInGwei: feeInGwei,
            createdAtBatchId: _summary.nextBatchId,
            blobByteOffset: blobByteOffset,
            blobByteSize: blobByteSize,
            blobCreatedIn: uint64(block.number)
        });

        queue[tail++] = inclusion;

        emit ForcedInclusionStored(inclusion);
    }

    /// @inheritdoc IForcedInclusionStore
    /// @dev WARNING: The `nextBatchId` is trusted and should have been validated by the caller.
    ///     Since we allow this function to only be called by the inbox this is ok.
    function consumeOldestForcedInclusion(
        address _feeRecipient,
        uint64 _nextBatchId
    )
        external
        onlyFrom(address(inbox))
        nonReentrant
        returns (ForcedInclusion memory inclusion_)
    {
        // we only need to check the first one, since it will be the oldest.
        ForcedInclusion storage inclusion = queue[head];
        require(inclusion.createdAtBatchId != 0, NoForcedInclusionFound());

        inclusion_ = inclusion;

        lastProcessedAtBatchId = _nextBatchId;

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

    /// @dev Check if the oldest forced inclusion is due for a specific batch id.
    /// @param _batchId The batch id to check.
    /// @return True if the oldest forced inclusion is due for the specified batch id, false
    /// otherwise.
    function isOldestForcedInclusionDue(uint64 _batchId) external view returns (bool) {
        uint256 deadline = getOldestForcedInclusionDeadline();
        return deadline != type(uint256).max && _batchId >= deadline;
    }

    // @dev Override this function for easier testing blobs
    function _blobHash(uint8 blobIndex) internal view virtual returns (bytes32) {
        return blobhash(blobIndex);
    }
}
