// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {
    MessageHashUtils
} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

/// Note: No nonce checks. Do not use in production.
contract UserOpsSubmitter {
    struct UserOp {
        address target;
        uint256 value;
        bytes data;
    }

    address public immutable owner;

    event BatchExecuted(address indexed executor, uint256 opsCount);
    event OperationExecuted(
        uint256 indexed index, address indexed target, uint256 value, bool success
    );

    constructor(address _owner) {
        if (_owner == address(0)) revert INVALID_OWNER();
        owner = _owner;
    }

    function executeBatch(UserOp[] calldata _ops, bytes calldata _signature) external {
        if (_ops.length == 0) revert EMPTY_BATCH();

        bytes32 digest = keccak256(abi.encode(_ops));
        // Convert to Ethereum signed message hash to support standard personal_sign from wallets
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(digest);
        address signer = ECDSA.recover(ethSignedHash, _signature);

        if (signer != owner) revert INVALID_SIGNATURE();

        uint256 opsLength = _ops.length;
        for (uint256 i; i < opsLength;) {
            UserOp calldata op = _ops[i];

            (bool success,) = op.target.call{ value: op.value }(op.data);

            emit OperationExecuted(i, op.target, op.value, success);

            if (!success) revert OPERATION_FAILED(i);

            unchecked {
                ++i;
            }
        }

        emit BatchExecuted(msg.sender, opsLength);
    }

    function getDigest(UserOp[] calldata _ops) external pure returns (bytes32 digest_) {
        return keccak256(abi.encode(_ops));
    }

    receive() external payable { }

    error INVALID_OWNER();
    error EMPTY_BATCH();
    error INVALID_SIGNATURE();
    error OPERATION_FAILED(uint256 index);
}
