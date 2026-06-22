// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DateTimeLib} from "solady/utils/DateTimeLib.sol";
import {LibString} from "solady/utils/LibString.sol";

library DateTimeUtils {
    using LibString for string;

    /*
     * @dev Convert a DER-encoded time to a unix timestamp
     * @param x509Time The DER-encoded time
     * @return The unix timestamp
     */
    function fromDERToTimestamp(bytes memory x509Time) internal pure returns (uint256) {
        uint16 yrs;
        uint8 mnths;
        uint8 dys;
        uint8 hrs;
        uint8 mins;
        uint8 secs;
        uint8 offset;

        if (x509Time.length == 13) {
            if (uint8(x509Time[0]) - 48 < 5) yrs += 2000;
            else yrs += 1900;
        } else {
            yrs += (uint8(x509Time[0]) - 48) * 1000 + (uint8(x509Time[1]) - 48) * 100;
            offset = 2;
        }
        yrs += (uint8(x509Time[offset + 0]) - 48) * 10 + uint8(x509Time[offset + 1]) - 48;
        mnths = (uint8(x509Time[offset + 2]) - 48) * 10 + uint8(x509Time[offset + 3]) - 48;
        dys += (uint8(x509Time[offset + 4]) - 48) * 10 + uint8(x509Time[offset + 5]) - 48;
        hrs += (uint8(x509Time[offset + 6]) - 48) * 10 + uint8(x509Time[offset + 7]) - 48;
        mins += (uint8(x509Time[offset + 8]) - 48) * 10 + uint8(x509Time[offset + 9]) - 48;
        secs += (uint8(x509Time[offset + 10]) - 48) * 10 + uint8(x509Time[offset + 11]) - 48;

        return DateTimeLib.dateTimeToTimestamp(yrs, mnths, dys, hrs, mins, secs);
    }

    /// @dev iso follows pattern: "YYYY-MM-DDTHH:mm:ssZ"
    function fromISOToTimestamp(string memory iso) internal pure returns (uint256) {
        require(bytes(iso).length == 20, "invalid iso string length");
        uint256 y = stringToUint(iso.slice(0, 4));
        uint256 m = stringToUint(iso.slice(5, 7));
        uint256 d = stringToUint(iso.slice(8, 10));
        uint256 h = stringToUint(iso.slice(11, 13));
        uint256 min = stringToUint(iso.slice(14, 16));
        uint256 s = stringToUint(iso.slice(17, 19));

        return DateTimeLib.dateTimeToTimestamp(y, m, d, h, min, s);
    }

    // https://ethereum.stackexchange.com/questions/10932/how-to-convert-string-to-int
    function stringToUint(string memory s) private pure returns (uint256 result) {
        bytes memory b = bytes(s);
        result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }
}
