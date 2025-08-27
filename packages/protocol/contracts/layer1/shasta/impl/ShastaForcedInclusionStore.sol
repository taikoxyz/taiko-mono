// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

/// @title ShastaForcedInclusionStore
/// @dev Abstract contract for storing and managing forced inclusion requests. Forced inclusions
/// allow users to pay a fee to ensure their transactions are included in a block. The contract
/// maintains a FIFO queue of inclusion requests.
/// @dev Inclusion delay is measured in seconds, since we don't have an easy way to get batch number
/// in the Shasta design.
/// @dev We only allow one forced inclusion per L1 transaction to avoid spamming the proposer.
/// @dev Forced inclusions are limited to 1 blob only, and one L2 block only(this and other protocol
/// constrains are enforced by the node and verified by the prover)
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaForcedInclusionStore is EssentialContract, IForcedInclusionStore {
    using LibAddress for address;
    using LibMath for uint256;

    uint64 public immutable inclusionDelay; // measured in seconds
    uint64 public immutable feeInGwei;

    mapping(uint256 id => ForcedInclusion inclusion) public queue; //slot 1
    // --slot 2--
    /// @notice The index of the oldest forced inclusion in the queue. This is where items will be
    /// dequeued.
    uint64 public head;
    /// @notice The index of the next free slot in the queue. This is where items will be enqueued.
    uint64 public tail;
    /// @notice The last time a forced inclusion was processed.
    uint64 public lastProcessedAt;
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
        uint64 _inclusionDelay,
        uint64 _feeInGwei
    )
        nonZeroValue(_inclusionDelay)
        nonZeroValue(_feeInGwei)
        EssentialContract()
    {
        inclusionDelay = _inclusionDelay;
        feeInGwei = _feeInGwei;
    }

    /// @inheritdoc IForcedInclusionStore
    function storeForcedInclusion(LibBlobs.BlobReference memory _blobReference)
        external
        payable
        onlyStandaloneTx
        whenNotPaused
    {
        require(msg.value == feeInGwei * 1 gwei, IncorrectFee());

        LibBlobs.BlobSlice memory blobSlice =
            LibBlobs.validateBlobReference(_blobReference, _blobhash);
        ForcedInclusion memory inclusion =
            ForcedInclusion({ feeInGwei: feeInGwei, blobSlice: blobSlice });

        queue[tail++] = inclusion;

        emit ForcedInclusionStored(inclusion);
    }

    /// @inheritdoc IForcedInclusionStore
    function isOldestForcedInclusionDue() external view returns (bool) {
        return _isOldestForcedInclusionDue();
    }

    // ---------------------------------------------------------------
    // Internal Functions (accessible by inheriting contracts)
    // ---------------------------------------------------------------

    /// @dev Internal implementation of consuming forced inclusions
    /// @notice Consumes up to _count forced inclusions from the queue
    /// @param _feeRecipient The address to receive the fees from all consumed inclusions
    /// @param _count The maximum number of forced inclusions to consume
    /// @return inclusions_ Array of consumed forced inclusions (may be less than _count if queue
    /// has fewer)
    function _consumeForcedInclusions(
        address _feeRecipient,
        uint256 _count
    )
        internal
        returns (ForcedInclusion[] memory inclusions_)
    {
        // Early exit if no inclusions requested or queue is empty
        if (_count == 0 || head == tail) {
            return new ForcedInclusion[](0);
        }

        // Calculate actual number to process (min of requested and available)
        uint256 available = tail - head;
        uint256 toProcess = _count > available ? available : _count;

        inclusions_ = new ForcedInclusion[](toProcess);
        uint256 totalFees;

        unchecked {
            for (uint256 i; i < toProcess; ++i) {
                inclusions_[i] = queue[head + i];
                totalFees += inclusions_[i].feeInGwei;

                // Delete the inclusion from storage
                delete queue[head + i];
            }

            // Update head and lastProcessedAt after all processing
            head += uint64(toProcess);
            lastProcessedAt = uint64(block.timestamp);

            // Send all fees in one transfer
            if (totalFees > 0) {
                _feeRecipient.sendEtherAndVerify(totalFees * 1 gwei);
            }
        }
    }

    /// @dev Internal implementation to check if the oldest forced inclusion is due
    /// @return True if the oldest forced inclusion is due, false otherwise
    function _isOldestForcedInclusionDue() internal view returns (bool) {
        // Early exit for empty queue (most common case)
        if (head == tail) return false;

        ForcedInclusion storage inclusion = queue[head];
        // Early exit if slot is empty
        if (inclusion.blobSlice.timestamp == 0) return false;

        // Only calculate deadline if we have a valid inclusion
        unchecked {
            uint256 deadline =
                uint256(lastProcessedAt).max(inclusion.blobSlice.timestamp) + inclusionDelay;
            return block.timestamp >= deadline;
        }
    }

    function _blobhash(uint256 _blobIndex) private view returns (bytes32) {
        return blobhash(_blobIndex);
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BlobNotFound();
    error IncorrectFee();
    error MultipleCallsInOneTx();
    error NoForcedInclusionFound();
    error ForcedInclusionDue();
}
