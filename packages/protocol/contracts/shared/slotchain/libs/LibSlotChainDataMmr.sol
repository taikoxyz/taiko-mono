// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LibSlotChainConstants } from "./LibSlotChainConstants.sol";
import { LibSlotChainEncoding } from "./LibSlotChainEncoding.sol";

/// @title Slot Chain bounded data MMR algorithms
/// @custom:security-contact security@taiko.xyz
library LibSlotChainDataMmr {
    /// @dev Previews one append and virtually substitutes the sole changed peak.
    function previewAppend(
        bytes32[12] storage _peaks,
        uint16 _count,
        bytes32 _leaf
    )
        internal
        view
        returns (uint8 writeHeight_, bytes32 carriedPeak_, uint16 newCount_, bytes32 newRoot_)
    {
        if (_count >= LibSlotChainConstants.MAX_DATA_RECORDS) {
            revert MmrCapacityExceeded();
        }
        carriedPeak_ = _leaf;
        while (((_count >> writeHeight_) & 1) == 1) {
            carriedPeak_ = LibSlotChainEncoding.hashDataNode(
                writeHeight_, _peaks[writeHeight_], carriedPeak_
            );
            ++writeHeight_;
        }
        newCount_ = _count + 1;
        newRoot_ = _root(_peaks, newCount_, true, writeHeight_, carriedPeak_);
    }

    /// @dev Bags exactly the set-bit peaks in ascending height order.
    function root(
        bytes32[12] storage _peaks,
        uint16 _count
    )
        internal
        view
        returns (bytes32 root_)
    {
        if (_count > LibSlotChainConstants.MAX_DATA_RECORDS) revert InvalidMmrCount();
        return _root(_peaks, _count, false, 0, bytes32(0));
    }

    /// @dev Verifies the canonical proof whose structure is fully derived from count and index.
    function verifyInclusion(
        uint16 _count,
        uint16 _index,
        bytes32 _leaf,
        bytes32[] calldata _mountainSiblings,
        bytes32[] calldata _otherPeaks,
        bytes32 _expectedRoot
    )
        internal
        pure
        returns (bool valid_)
    {
        if (_count == 0 || _count > LibSlotChainConstants.MAX_DATA_RECORDS || _index >= _count) {
            return false;
        }

        (bool found, uint8 targetHeight, uint16 targetBase) = _targetMountain(_count, _index);
        if (
            !found || _mountainSiblings.length != targetHeight
                || _otherPeaks.length + 1 != _popcount(_count)
        ) {
            return false;
        }

        bytes32 targetPeak =
            _foldMountain(uint256(_index) - uint256(targetBase), _leaf, _mountainSiblings);
        return _proofRoot(_count, targetHeight, targetPeak, _otherPeaks) == _expectedRoot;
    }

    /// @dev Bags storage peaks while optionally replacing one newly carried peak.
    function _root(
        bytes32[12] storage _peaks,
        uint16 _count,
        bool _hasOverride,
        uint8 _overrideHeight,
        bytes32 _overridePeak
    )
        private
        view
        returns (bytes32 root_)
    {
        uint8 peakCount = _popcount(_count);
        bytes memory encodedPeaks;
        for (uint8 height; height < LibSlotChainConstants.DATA_MMR_DEPTH; ++height) {
            if (((_count >> height) & 1) == 0) continue;
            bytes32 peak =
                _hasOverride && height == _overrideHeight ? _overridePeak : _peaks[height];
            encodedPeaks = bytes.concat(encodedPeaks, bytes1(height), peak);
        }
        return LibSlotChainEncoding.hashDataBag(_count, peakCount, encodedPeaks);
    }

    /// @dev Folds the exact target-height siblings using local index bits for orientation.
    function _foldMountain(
        uint256 _localIndex,
        bytes32 _leaf,
        bytes32[] calldata _siblings
    )
        private
        pure
        returns (bytes32 peak_)
    {
        peak_ = _leaf;
        for (uint8 height; height < _siblings.length; ++height) {
            bytes32 sibling = _siblings[height];
            peak_ = ((_localIndex >> height) & 1) == 1
                ? LibSlotChainEncoding.hashDataNode(height, sibling, peak_)
                : LibSlotChainEncoding.hashDataNode(height, peak_, sibling);
        }
    }

    /// @dev Rebuilds the ascending-height bag while deriving all omitted peak heights.
    function _proofRoot(
        uint16 _count,
        uint8 _targetHeight,
        bytes32 _targetPeak,
        bytes32[] calldata _otherPeaks
    )
        private
        pure
        returns (bytes32 root_)
    {
        bytes memory encodedPeaks;
        uint256 otherPeakIndex;
        for (uint8 height; height < LibSlotChainConstants.DATA_MMR_DEPTH; ++height) {
            if (((_count >> height) & 1) == 0) continue;
            bytes32 peak;
            if (height == _targetHeight) {
                peak = _targetPeak;
            } else {
                peak = _otherPeaks[otherPeakIndex];
                ++otherPeakIndex;
            }
            encodedPeaks = bytes.concat(encodedPeaks, bytes1(height), peak);
        }
        assert(otherPeakIndex == _otherPeaks.length);
        return LibSlotChainEncoding.hashDataBag(_count, uint8(_otherPeaks.length + 1), encodedPeaks);
    }

    /// @dev Derives the unique left-to-right mountain containing the requested index.
    function _targetMountain(
        uint16 _count,
        uint16 _index
    )
        private
        pure
        returns (bool found_, uint8 height_, uint16 base_)
    {
        uint256 base;
        for (uint8 cursor = uint8(LibSlotChainConstants.DATA_MMR_DEPTH); cursor > 0;) {
            --cursor;
            if (((_count >> cursor) & 1) == 0) continue;
            uint256 size = uint256(1) << cursor;
            if (uint256(_index) < base + size) {
                return (true, cursor, uint16(base));
            }
            base += size;
        }
    }

    /// @dev Counts meaningful peaks for one bounded record count.
    function _popcount(uint16 _count) private pure returns (uint8 count_) {
        for (uint8 height; height < LibSlotChainConstants.DATA_MMR_DEPTH; ++height) {
            if (((_count >> height) & 1) == 1) ++count_;
        }
    }

    error MmrCapacityExceeded();
    error InvalidMmrCount();
}
