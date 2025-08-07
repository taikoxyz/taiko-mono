// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibNames.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";

/// @title ForcedInclusionStore
/// @dev A contract for storing and managing forced inclusion requests. Forced inclusions allow
/// users to pay a fee to ensure their transactions are included in a block. The contract maintains
/// a FIFO queue of inclusion requests.
/// @dev Inclusion delay is measured in seconds, since we don't have an easy way to get batch number
/// in the Shasta design.
/// @dev We only allow one forced inclusion per L1 transaction to avoid spamming the proposer.
/// @dev Forced inclusions are limited to 1 blob only, and one L2 block only(this and other protocol
/// constrains are enforced by the node and verified by the prover)
/// @custom:security-contact security@taiko.xyz
contract ForcedInclusionStore is EssentialContract, IForcedInclusionStore {
    using LibAddress for address;
    using LibMath for uint256;

    uint64 public immutable inclusionDelay; // measured in seconds
    uint64 public immutable feeInGwei;
    address public immutable inbox;

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
        uint64 _feeInGwei,
        address _inbox
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

    /// @inheritdoc IForcedInclusionStore
    function storeForcedInclusion(
        uint256 blobIndex,
        uint32 blobByteOffset,
        uint32 blobByteSize
    )
        external
        payable
        onlyStandaloneTx
        whenNotPaused
    {
        bytes32 blobHash = blobhash(blobIndex);
        require(blobHash != bytes32(0), BlobNotFound());
        require(msg.value == feeInGwei * 1 gwei, IncorrectFee());

        ForcedInclusion memory inclusion = ForcedInclusion({
            blobHash: blobHash,
            feeInGwei: feeInGwei, // we already validated it above
            submittedAt: uint64(block.timestamp),
            blobByteOffset: blobByteOffset,
            blobByteSize: blobByteSize
        });

        queue[tail++] = inclusion;

        emit ForcedInclusionStored(inclusion);
    }

    /// @inheritdoc IForcedInclusionStore
    /// @dev Only the inbox contract can call it since we don't do any validation here
    function consumeOldestForcedInclusion(address _feeRecipient)
        external
        onlyFrom(inbox)
        nonReentrant
        returns (ForcedInclusion memory inclusion_)
    {
        // we only need to check the first one, since it will be the oldest.
        ForcedInclusion storage inclusion = queue[head];
        require(inclusion.submittedAt != 0, NoForcedInclusionFound());

        inclusion_ = inclusion;

        lastProcessedAt = uint64(block.timestamp);

        unchecked {
            delete queue[head++]; // delete element at head AND THEN increment head
            _feeRecipient.sendEtherAndVerify(inclusion_.feeInGwei * 1 gwei);
        }
    }

    /// @inheritdoc IForcedInclusionStore
    function isOldestForcedInclusionDue() external view returns (bool) {
        uint256 deadline = getOldestForcedInclusionDeadline();
        return deadline != type(uint256).max && block.timestamp >= deadline;
    }

    /// @notice Get the deadline for the oldest forced inclusion.
    /// @return The deadline for the oldest forced inclusion or `type(uint256).max` if there is no
    /// forced inclusion in the queue
    function getOldestForcedInclusionDeadline() public view returns (uint256) {
        if (head == tail) return type(uint256).max;

        ForcedInclusion storage inclusion = queue[head];
        // there is no forced inclusion in the queue
        if (inclusion.submittedAt == 0) return type(uint256).max;

        unchecked {
            return uint256(lastProcessedAt).max(inclusion.submittedAt) + inclusionDelay;
        }
    }
}
