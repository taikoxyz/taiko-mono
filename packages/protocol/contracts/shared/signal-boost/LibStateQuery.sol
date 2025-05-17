// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IStateQuery.sol";

/// @title LibStateQuery
/// @notice Library for hashing state queries and results.
/// @custom:security-contact security@taiko.xyz
library LibStateQuery {
    error InvalidParamSizes();

    /// @notice Hashes the state queries and results into a signal.
    /// @param _chainId The chain ID of the state queries.
    /// @param _queryTimestamp The timestamp of the state queries.
    /// @param _queries The state queries.
    /// @param _results The state results.
    /// @return The signal.
    function hashQueriesToSignal(
        uint256 _chainId,
        uint256 _queryTimestamp,
        IStateQuery.Query[] calldata _queries,
        IStateQuery.QueryResult[] memory _results
    )
        internal
        pure
        returns (bytes32)
    {
        require(_queries.length == _results.length, InvalidParamSizes());
        uint256 n = _queries.length;
        bytes32[] memory leaves = new bytes32[](n);
        for (uint256 i; i < n; ++i) {
            leaves[i] = keccak256(abi.encode(_queries[i], _results[i]));
        }

        uint256 offset;
        uint256 size = n;
        while (size > 1) {
            for (uint256 i = 0; i < size - 1; i += 2) {
                leaves[offset + i / 2] =
                    keccak256(abi.encode(leaves[offset + i], leaves[offset + i + 1]));
            }
            if (size % 2 == 1) {
                leaves[offset + size / 2] = leaves[offset + size - 1];
            }
            offset += size;
            size = (size + 1) / 2;
        }

        return keccak256(abi.encode(_chainId, _queryTimestamp, leaves[0]));
    }
}
