// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

/// @author dantaik <dan@taiko.xyz>
contract PIDController {
    int64 public constant DECIMALS = 1 << 32;

    int64 public immutable pweight;
    int64 public immutable iweight;
    int64 public immutable dweight;

    // use int128 so we only need 1 sstore
    // when funciton `command` is called.
    int128 public lastError;
    int128 public integral;
    uint256[49] private __gap;

    constructor(
        int64 _pweight,
        int64 _iweight,
        int64 _dweight
    ) {
        pweight = _pweight;
        iweight = _iweight;
        dweight = _dweight;
    }

    /// @dev Issue a new command based on the last measurement.
    /// @param processValue The last measured value, scaled by DECIMALS. Note
    ///        that this function always assume the set point is 100%,
    ///        scaled by DECIMALS.
    /// @param duration The duration since last measurement.
    /// @return output The output of the command.
    function command(int64 processValue, int64 duration)
        public
        returns (int128 output)
    {
        require(duration > 0, "PID:duration");
        int64 error = DECIMALS - processValue;
        int128 proportional = error * pweight;
        int128 derivative = ((error - lastError) * dweight) / duration;
        lastError = error;
        integral += error * iweight;
        return (proportional + integral + derivative) / DECIMALS;
    }
}
