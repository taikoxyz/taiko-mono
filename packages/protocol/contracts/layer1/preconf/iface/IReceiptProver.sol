// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ILookahead
/// @custom:security-contact security@taiko.xyz
interface IReceiptProver {
    struct Receipt {
        uint64 blockId;
        uint64 chainId;
        uint32 position;
        bool isExecutionPreconf;
        bytes32 txHash;
        bytes signature;
    }


    event ReceiptViolationProved(
        address indexed preconfer, 
        Receipt receipt
    );



    function proveReceiptViolation(
        Receipt calldata _receipt,
        bytes calldata _proof
    )
        external
        returns (address preconfer_);
}
