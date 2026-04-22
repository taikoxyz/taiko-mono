// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockBeaconBlockRoot {
    mapping(uint256 => bytes32) internal blockRoots;
    mapping(uint256 => bool) internal configured;

    function set(uint256 timestamp, bytes32 root) external {
        blockRoots[timestamp] = root;
        configured[timestamp] = true;
    }

    fallback(bytes calldata data) external payable returns (bytes memory) {
        uint256 ts = abi.decode(data, (uint256));
        if (configured[ts]) {
            return abi.encode(blockRoots[ts]);
        }
        // If no explicit root was configured, fall back to a deterministic non-zero value to keep
        // randomness usable without manual setup in tests that rely on preconfer selection.
        return abi.encode(bytes32(ts));
    }

    receive() external payable { }
}
