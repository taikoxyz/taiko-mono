// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Multicall {
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    function multicall(Call[] calldata calls) external payable returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) =
                calls[i].target.call{ value: calls[i].value }(calls[i].data);
            require(success, "Multicall: call failed");
            results[i] = result;
        }
    }

    receive() external payable { }
}
