// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../iface/IEtnaInbox.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

/// @title LibEtnaForcedInclusion
/// @notice The Etna Inbox's calldata forced inclusion queue operations.
/// @dev Preserves Shasta's fee formula without depending on its blob queue or linked library.
/// @custom:security-contact security@taiko.xyz
library LibEtnaForcedInclusion {
    using LibMath for uint256;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev Queue entries are retained after consumption. The pointers share one storage word.
    struct Storage {
        mapping(uint256 index => IEtnaInbox.ForcedInclusion entry) queue;
        uint48 head;
        uint48 tail;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Returns `baseFee * (threshold + pending) / threshold`, capped at `type(uint64).max`.
    /// Reproduces `LibForcedInclusion.getCurrentForcedInclusionFee`.
    /// @param $ The forced inclusion queue.
    /// @param _baseFeeInGwei The fee in Gwei with an empty queue.
    /// @param _feeDoubleThreshold The number of pending entries at which the fee doubles.
    /// @return feeInGwei_ The fee in Gwei for the next entry.
    function currentFee(
        Storage storage $,
        uint64 _baseFeeInGwei,
        uint64 _feeDoubleThreshold
    )
        internal
        view
        returns (uint64 feeInGwei_)
    {
        require(_feeDoubleThreshold > 0, InvalidFeeDoubleThreshold());

        (uint48 head, uint48 tail) = ($.head, $.tail);
        uint256 numPending = uint256(tail - head);

        uint256 multipliedFee =
            uint256(_baseFeeInGwei) * (uint256(_feeDoubleThreshold) + numPending);
        feeInGwei_ = uint64((multipliedFee / _feeDoubleThreshold).min(type(uint64).max));
    }

    /// @dev Moves `head` to `_newHead` and sums the fees of the entries in `[head, _newHead)`.
    /// Entries are not deleted. The caller must ensure `head <= _newHead <= tail`.
    /// @param $ The forced inclusion queue.
    /// @param _newHead The new head.
    /// @return feesInGwei_ The total fee in Gwei of the consumed entries.
    function consume(Storage storage $, uint48 _newHead) internal returns (uint256 feesInGwei_) {
        // Fewer than 2^48 uint64 fees cannot overflow a uint256 sum.
        unchecked {
            for (uint256 i = $.head; i < _newHead; ++i) {
                feesInGwei_ += uint256($.queue[i].feeInGwei);
            }
        }
        $.head = _newHead;
    }

    /// @dev Reads pending entries with the same bounds as the original queue getters.
    /// @param $ The forced inclusion queue.
    /// @param _start The first queue index; must be in [head, tail).
    /// @param _maxCount The maximum number of entries to return.
    /// @return inclusions_ Pending entries, or an empty array for an invalid range.
    function getForcedInclusions(
        Storage storage $,
        uint48 _start,
        uint48 _maxCount
    )
        internal
        view
        returns (IEtnaInbox.ForcedInclusion[] memory inclusions_)
    {
        (uint48 head, uint48 tail) = ($.head, $.tail);
        if (_start < head || _start >= tail || _maxCount == 0) {
            return new IEtnaInbox.ForcedInclusion[](0);
        }
        uint256 count = uint256(tail - _start).min(_maxCount);
        inclusions_ = new IEtnaInbox.ForcedInclusion[](count);
        for (uint256 i; i < count; ++i) {
            inclusions_[i] = $.queue[i + _start];
        }
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidFeeDoubleThreshold();
}
