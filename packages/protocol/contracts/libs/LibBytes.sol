// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library LibBytes {
    error INNER_ERROR(bytes innerError);

    // Taken from:
    // https://github.com/0xPolygonHermez/zkevm-contracts/blob/main/contracts/PolygonZkEVMBridge.sol#L835-L860
    /// @notice Function to convert returned data to string
    /// returns 'NOT_VALID_ENCODING' as fallback value.
    function toString(bytes memory _data) internal pure returns (string memory) {
        if (_data.length >= 64) {
            return abi.decode(_data, (string));
        } else if (_data.length == 32) {
            // Since the strings on bytes32 are encoded left-right, check the first zero in the data
            uint256 nonZeroBytes;
            while (nonZeroBytes < 32 && _data[nonZeroBytes] != 0) {
                ++nonZeroBytes;
            }

            // If the first one is 0, we do not handle the encoding
            if (nonZeroBytes == 0) return "";

            // Create a byte array with nonZeroBytes length
            bytes memory bytesArray = new bytes(nonZeroBytes);
            for (uint256 i; i < nonZeroBytes; ++i) {
                bytesArray[i] = _data[i];
            }
            return string(bytesArray);
        } else {
            return "";
        }
    }

    // Taken from:
    // https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/BoringBatchable.sol
    /// @dev Helper function to extract a useful revert message from a failed call.
    /// If the returned data is malformed or not correctly abi encoded then this call can fail
    /// itself.
    function revertWithExtractedError(bytes memory _returnData) internal pure {
        // If the _res length is less than 68, then
        // the transaction failed with custom error or silently (without a revert message)
        if (_returnData.length < 68) revert INNER_ERROR(_returnData);

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        revert(abi.decode(_returnData, (string))); // All that remains is the revert string
    }
}
