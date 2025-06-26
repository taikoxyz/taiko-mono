// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/libs/LibAddress.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

/// @title LibData2
/// @custom:security-contact security@taiko.xyz
library LibData2 {
    error SummaryMismatch();

    struct Env {
        I.Config config;
        address bondToken;
        address verifier;
        address inboxWrapper;
        address signalService;
        bytes32 prevSummaryHash;
    }

    function updateSummary(I.State storage $, I.Summary memory _summary, bool _paused) internal {
        uint256 newHash = uint256(keccak256(abi.encode(_summary)));
        newHash &= ~uint256(1);
        newHash |= (_paused ? 1 : 0);
        $.summaryHash = bytes32(newHash);
        // emit I.SummaryUpdated(_summary, _paused);
    }

    function validateSummary(
        I.State storage $,
        I.Summary calldata _summary
    )
        internal
        view
        returns (bool paused_)
    {
        bytes32 summaryHash = $.summaryHash;
        require(summaryHash >> 1 == keccak256(abi.encode(_summary)) >> 1, SummaryMismatch());

        return uint256(summaryHash) & 1 == 1;
    }

    function loadBatchIdAndPartialParentHash(
        I.State storage $,
        uint256 _slot
    )
        internal
        view
        returns (uint48 embededBatchId_, bytes32 partialParentHash_)
    {
        bytes32 value = $.transitions[_slot][1].batchIdAndPartialParentHash; // 1 SLOAD
        embededBatchId_ = uint48(uint256(value));
        partialParentHash_ = value >> 48;
    }

    function encodeBatchIdAndPartialParentHash(
        uint48 batchId_,
        bytes32 partialParentHash_
    )
        internal
        pure
        returns (bytes32)
    {
        uint256 v = uint256(partialParentHash_) & ~type(uint48).max | batchId_;
        return bytes32(v);
    }
}
