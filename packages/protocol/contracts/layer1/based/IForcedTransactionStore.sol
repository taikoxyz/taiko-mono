// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IForcedTransactionStore
/// @custom:security-contact security@taiko.xyz
interface IForcedTransactionStore {
    function consumeForcedTransactions()
        external
        returns (bytes memory forcedTxs_);
}
