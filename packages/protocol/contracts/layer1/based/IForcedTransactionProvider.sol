// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IForcedTransactionProvider
/// @custom:security-contact security@taiko.xyz
interface IForcedTransactionProvider {
    function consumeForcedTransactions()
        external
        returns (bytes memory forcedTxs_);
}
