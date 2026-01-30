// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Multicall {
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    error MULTICALL_CALL_FAILED(uint256 index, bytes returnData);

    function multicall(Call[] calldata calls) external payable returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) =
                calls[i].target.call{ value: calls[i].value }(calls[i].data);
            if (!success) revert MULTICALL_CALL_FAILED(i, result);
            results[i] = result;
        }
    }

    receive() external payable { }
}
