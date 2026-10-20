// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Test-only workload for execution-layer zk-gas admission tests.
/// @dev At alethia-reth 1e25b484, three failed 50,000-gas point-evaluation calls cost
/// 128,850,000 zk gas before opcode and transaction charges, exceeding the 100,000,000 limit.
/// @custom:security-contact security@taiko.xyz
contract ZkGasFixture {
    /// @notice Executes three invalid point-evaluation calls and preserves their results.
    /// @dev Invalid versioned-hash input consumes each call's full gas allowance. Returning every
    /// result keeps the calls observable while allowing ordinary EVM execution to continue.
    /// @return first_ Whether the first precompile call succeeded.
    /// @return second_ Whether the second precompile call succeeded.
    /// @return third_ Whether the third precompile call succeeded.
    function consumeZkGas() external view returns (bool first_, bool second_, bool third_) {
        bytes memory input = new bytes(192);
        (first_,) = address(0x0a).staticcall{gas: 50_000}(input);
        (second_,) = address(0x0a).staticcall{gas: 50_000}(input);
        (third_,) = address(0x0a).staticcall{gas: 50_000}(input);
    }

    /// @notice Reverts deterministically to test inclusion of execution-failing transactions.
    function revertAlways() external pure {
        revert FixtureReverted();
    }

    error FixtureReverted();
}
