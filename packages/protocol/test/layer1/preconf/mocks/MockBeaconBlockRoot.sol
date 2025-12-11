// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockBeaconBlockRoot {
    mapping(uint256 => bytes32) internal blockRoots;

    function set(uint256 timestamp, bytes32 root) external {
        blockRoots[timestamp] = root;
    }

    fallback(bytes calldata data) external payable returns (bytes memory) {
        uint256 ts = abi.decode(data, (uint256));
        bytes32 root = blockRoots[ts];
        // If no explicit root was configured, fall back to a deterministic non-zero value to keep
        // randomness usable without manual setup in tests that rely on preconfer selection.
        return abi.encode(root == bytes32(0) ? bytes32(ts) : root);
    }

    receive() external payable { }
}
