// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../../libs/LibMath.sol";
import "../LibData.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Utils {
    uint64 public constant MASK_HALT = 1 << 0;

    event Halted(bool halted);

    function halt(LibData.State storage s, bool toHalt) public {
        require(isBitOne(s.statusBits, MASK_HALT) != toHalt, "L1:precondition");
        setBit(s.statusBits, MASK_HALT, toHalt);
        emit Halted(toHalt);
    }

    function isHalted(LibData.State storage s) public view returns (bool) {
        return isBitOne(s.statusBits, MASK_HALT);
    }

    function setBit(uint64 bits, uint256 mask, bool one) private {}

    function isBitOne(uint64 bits, uint64 mask) private pure returns (bool) {
        return bits & mask != 0;
    }
}
