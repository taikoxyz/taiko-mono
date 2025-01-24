// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibMath.sol";
import "./IForcedInclusionStore.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibStrings.sol";

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

    uint256 public immutable inclusionDelay;
    uint256 public immutable fee;

    mapping(uint256 id => ForcedInclusion inclusion) public queue; // slot 1
    uint64 public head; // slot 2
    uint64 public tail;
    uint128 private __reserved1;

    uint256[48] private __gap;

    constructor(
        address _resolver,
        uint256 _inclusionDelay,
        uint256 _fee
    )
        EssentialContract(_resolver)
    {
        require(_inclusionDelay != 0 && _inclusionDelay % SECONDS_PER_BLOCK == 0, InvalidParams());
        require(_fee != 0, InvalidParams());

        inclusionDelay = _inclusionDelay;
        fee = _fee;
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
    {
        bytes32 blobHash = _blobHash(blobIndex);
        require(blobHash != bytes32(0), BlobNotFound());
        require(msg.value == fee, IncorrectFee());

        ForcedInclusion memory inclusion = ForcedInclusion({
            blobHash: blobHash,
            fee: msg.value,
            createdAt: uint64(block.timestamp),
            blobByteOffset: blobByteOffset,
            blobByteSize: blobByteSize
        });

        queue[tail++] = inclusion;

        emit ForcedInclusionStored(inclusion);
    }

    function consumeForcedInclusion(address _feeRecipient)
        external
        onlyFromNamed(LibStrings.B_TAIKO_FORCED_INCLUSION_INBOX)
        returns (ForcedInclusion memory inclusion_)
    {
        // we only need to check the first one, since it will be the oldest.
        uint64 _head = head;
        ForcedInclusion storage inclusion = queue[_head];

        if (inclusion.createdAt != 0 && block.timestamp >= inclusionDelay + inclusion.createdAt) {
            inclusion_ = inclusion;
            _feeRecipient.sendEtherAndVerify(inclusion.fee);
            delete queue[_head];
            head = _head + 1;
            emit ForcedInclusionConsumed(inclusion);
        }
    }

    // @dev Override this function for easier testing blobs
    function _blobHash(uint8 blobIndex) internal view virtual returns (bytes32) {
        return blobhash(blobIndex);
    }
}
