// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/libs/LibAddress.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

/// @title LibData2
/// @custom:security-contact security@taiko.xyz
library LibData2 {
    bytes32 internal constant FIRST_TRAN_PARENT_HASH_PLACEHOLDER = bytes32(type(uint256).max);

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
}
