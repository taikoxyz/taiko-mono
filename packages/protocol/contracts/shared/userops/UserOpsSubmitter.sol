// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

/// Note: No nonce checks. Do not use in production.
contract UserOpsSubmitter is EIP712 {
    struct UserOp {
        address target;
        uint256 value;
        bytes data;
    }

    bytes32 private constant _USEROP_TYPEHASH =
        keccak256("UserOp(address target,uint256 value,bytes data)");

    bytes32 private constant _EXECUTEBATCH_TYPEHASH =
        keccak256("ExecuteBatch(UserOp[] ops)UserOp(address target,uint256 value,bytes data)");

    address public immutable owner;

    event BatchExecuted(address indexed executor, uint256 opsCount);
    event OperationExecuted(
        uint256 indexed index, address indexed target, uint256 value, bool success
    );

    constructor(address _owner) EIP712("UserOpsSubmitter", "1") {
        if (_owner == address(0)) revert INVALID_OWNER();
        owner = _owner;
    }

    function executeBatch(UserOp[] calldata _ops, bytes calldata _signature) external {
        if (_ops.length == 0) revert EMPTY_BATCH();

        bytes32 structHash = _hashExecuteBatch(_ops);
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(digest, _signature);

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

    function getDigest(UserOp[] calldata _ops) external view returns (bytes32 digest_) {
        return _hashTypedDataV4(_hashExecuteBatch(_ops));
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    receive() external payable { }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    function _hashUserOp(UserOp calldata _op) internal pure returns (bytes32) {
        return keccak256(abi.encode(_USEROP_TYPEHASH, _op.target, _op.value, keccak256(_op.data)));
    }

    function _hashExecuteBatch(UserOp[] calldata _ops) internal pure returns (bytes32) {
        bytes32[] memory opHashes = new bytes32[](_ops.length);
        for (uint256 i; i < _ops.length;) {
            opHashes[i] = _hashUserOp(_ops[i]);
            unchecked {
                ++i;
            }
        }
        return
            keccak256(abi.encode(_EXECUTEBATCH_TYPEHASH, keccak256(abi.encodePacked(opHashes))));
    }

    error INVALID_OWNER();
    error EMPTY_BATCH();
    error INVALID_SIGNATURE();
    error OPERATION_FAILED(uint256 index);
}
