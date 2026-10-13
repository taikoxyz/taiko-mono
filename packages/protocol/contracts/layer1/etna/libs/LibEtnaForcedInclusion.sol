// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IForcedInclusionStore } from "src/layer1/core/iface/IForcedInclusionStore.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibForcedInclusion } from "src/layer1/core/libs/LibForcedInclusion.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

/// @title LibEtnaForcedInclusion
/// @notice The Etna Inbox's operations on the Shasta forced inclusion queue.
/// @dev `save` and `currentFee` reproduce `LibForcedInclusion.saveForcedInclusion` and
/// `LibForcedInclusion.getCurrentForcedInclusionFee` exactly. Those are `public`, so calling them
/// would make the Inbox bytecode depend on an externally linked library; these copies are
/// `internal`. A differential test keeps them equal to the library.
/// @custom:security-contact security@taiko.xyz
library LibEtnaForcedInclusion {
    using LibMath for uint256;

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Appends a single-blob entry at `tail` for the current fee and emits
    /// `IForcedInclusionStore.ForcedInclusionSaved`. Reproduces
    /// `LibForcedInclusion.saveForcedInclusion`.
    /// @param $ The forced inclusion queue.
    /// @param _baseFeeInGwei The fee in Gwei with an empty queue.
    /// @param _feeDoubleThreshold The number of pending entries at which the fee doubles.
    /// @param _blobReference The blob holding the forced transactions.
    /// @return refund_ The part of `msg.value` above the fee, for the caller to return.
    function save(
        LibForcedInclusion.Storage storage $,
        uint64 _baseFeeInGwei,
        uint64 _feeDoubleThreshold,
        LibBlobs.BlobReference memory _blobReference
    )
        internal
        returns (uint256 refund_)
    {
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.validateBlobReference(_blobReference);
        require(blobSlice.blobHashes.length == 1, LibForcedInclusion.OnlySingleBlobAllowed());

        uint64 requiredFeeInGwei = currentFee($, _baseFeeInGwei, _feeDoubleThreshold);
        uint256 requiredFee = requiredFeeInGwei * 1 gwei;
        require(msg.value >= requiredFee, LibForcedInclusion.InsufficientFee());

        IForcedInclusionStore.ForcedInclusion memory inclusion =
            IForcedInclusionStore.ForcedInclusion({
                feeInGwei: requiredFeeInGwei, blobSlice: blobSlice
            });

        $.queue[$.tail++] = inclusion;

        emit IForcedInclusionStore.ForcedInclusionSaved(inclusion);

        unchecked {
            refund_ = msg.value - requiredFee;
        }
    }

    /// @dev Returns `baseFee * (threshold + pending) / threshold`, capped at `type(uint64).max`.
    /// Reproduces `LibForcedInclusion.getCurrentForcedInclusionFee`.
    /// @param $ The forced inclusion queue.
    /// @param _baseFeeInGwei The fee in Gwei with an empty queue.
    /// @param _feeDoubleThreshold The number of pending entries at which the fee doubles.
    /// @return feeInGwei_ The fee in Gwei for the next entry.
    function currentFee(
        LibForcedInclusion.Storage storage $,
        uint64 _baseFeeInGwei,
        uint64 _feeDoubleThreshold
    )
        internal
        view
        returns (uint64 feeInGwei_)
    {
        require(_feeDoubleThreshold > 0, LibForcedInclusion.InvalidFeeDoubleThreshold());

        (uint48 head, uint48 tail) = ($.head, $.tail);
        uint256 numPending = uint256(tail - head);

        uint256 multipliedFee = _baseFeeInGwei * (_feeDoubleThreshold + numPending);
        feeInGwei_ = uint64((multipliedFee / _feeDoubleThreshold).min(type(uint64).max));
    }

    /// @dev Moves `head` to `_newHead` and sums the fees of the entries in `[head, _newHead)`.
    /// Entries are not deleted. The caller must ensure `head <= _newHead <= tail`.
    /// @param $ The forced inclusion queue.
    /// @param _newHead The new head.
    /// @return feesInGwei_ The total fee in Gwei of the consumed entries.
    function consume(
        LibForcedInclusion.Storage storage $,
        uint48 _newHead
    )
        internal
        returns (uint256 feesInGwei_)
    {
        // Fewer than 2^48 uint64 fees cannot overflow a uint256 sum.
        unchecked {
            for (uint256 i = $.head; i < _newHead; ++i) {
                feesInGwei_ += uint256($.queue[i].feeInGwei);
            }
        }
        $.head = _newHead;
    }
}
