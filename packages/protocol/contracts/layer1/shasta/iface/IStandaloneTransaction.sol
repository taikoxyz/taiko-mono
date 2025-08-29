// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title StandaloneTransaction
/// @dev Abstract contract for enforcing that a transaction is standalone.
/// @custom:security-contact security@taiko.xyz
abstract contract StandaloneTransaction {
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

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error MultipleCallsInOneTx();
}
