// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library CSVParser {
    function parseLine(string memory csvLine) external pure returns (uint256, address) {
        // Split the CSV line into an array of strings
        string[] memory values = _splitCSVLine(csvLine);

        // Convert the first and second values to uint256
        uint256 value1 = _stringToUint(values[0]);

        // Convert the third value to address
        address value2 = _stringToAddress(values[1]);

        return (value1, value2);
    }

    function _splitCSVLine(string memory line) private pure returns (string[] memory) {
        // Split the line using comma (,) as delimiter
        return _split(line, ",");
    }

    function _split(
        string memory _string,
        string memory _delimiter
    )
        private
        pure
        returns (string[] memory)
    {
        bytes memory byteArray = bytes(_string);
        bytes memory delimiter = bytes(_delimiter);

        uint256 delimiterCount = 1;
        for (uint256 i = 0; i < byteArray.length; i++) {
            if (byteArray[i] == delimiter[0]) {
                delimiterCount++;
            }
        }

        string[] memory parts = new string[](delimiterCount);
        uint256 partIndex = 0;
        uint256 lastIndex = 0;

        for (uint256 i = 0; i < byteArray.length; i++) {
            if (byteArray[i] == delimiter[0]) {
                parts[partIndex] = _substring(_string, lastIndex, i);
                partIndex++;
                lastIndex = i + 1;
            }
        }
        parts[partIndex] = _substring(_string, lastIndex, byteArray.length);

        return parts;
    }

    function _substring(
        string memory _str,
        uint256 _startIndex,
        uint256 _endIndex
    )
        private
        pure
        returns (string memory)
    {
        bytes memory byteArray = bytes(_str);
        bytes memory result = new bytes(_endIndex - _startIndex);
        for (uint256 i = _startIndex; i < _endIndex; i++) {
            result[i - _startIndex] = byteArray[i];
        }
        return string(result);
    }

    function _stringToUint(string memory _str) private pure returns (uint256) {
        uint256 result = 0;
        bytes memory b = bytes(_str);
        for (uint256 i = 0; i < b.length; i++) {
            if (uint8(b[i]) >= 48 && uint8(b[i]) <= 57) {
                result = result * 10 + (uint8(b[i]) - 48);
            }
        }
        return result;
    }

    function _stringToAddress(string memory _str) private pure returns (address) {
        bytes memory data = bytes(_str);
        uint160 result = 0;
        for (uint8 i = 0; i < data.length; i++) {
            result *= 16;
            if (uint8(data[i]) >= 48 && uint8(data[i]) <= 57) {
                result += uint8(data[i]) - 48;
            }
            if (uint8(data[i]) >= 65 && uint8(data[i]) <= 70) {
                result += uint8(data[i]) - 55;
            }
            if (uint8(data[i]) >= 97 && uint8(data[i]) <= 102) {
                result += uint8(data[i]) - 87;
            }
        }
        return address(uint160(result));
    }
}
