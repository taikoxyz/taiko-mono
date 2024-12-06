// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockBeaconBlockRoot {
    mapping(uint256 => bytes32) internal blockRoots;

    function set(uint256 timestamp, bytes32 root) external {
        blockRoots[timestamp] = root;
    }

    fallback(bytes calldata data) external payable returns (bytes memory) {
        bytes32 root = blockRoots[abi.decode(data, (uint256))];
        require(root != bytes32(0), "no root");
        return abi.encode(root);
    }

    receive() external payable { }
}
