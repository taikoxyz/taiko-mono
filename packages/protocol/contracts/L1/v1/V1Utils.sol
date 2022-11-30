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

    event WhitelistingEnabled(bool whitelistProposers, bool whitelistProvers);

    function halt(LibData.State storage s, bool toHalt) public {
        require(isHalted(s) != toHalt, "L1:precondition");
        setBit(s, MASK_HALT, toHalt);
        emit Halted(toHalt);
    }

    function enableWhitelisting(
        LibData.State storage s,
        bool whitelistProposers,
        bool whitelistProvers
    ) internal {
        s.whitelistProposers = whitelistProvers;
        s.whitelistProvers = whitelistProvers;
        emit WhitelistingEnabled(whitelistProposers, whitelistProvers);
    }

    function isHalted(LibData.State storage s) public view returns (bool) {
        return isBitOne(s, MASK_HALT);
    }

    function setBit(LibData.State storage s, uint64 mask, bool one) private {
        s.statusBits = one ? s.statusBits | mask : s.statusBits & ~mask;
    }

    function isBitOne(
        LibData.State storage s,
        uint64 mask
    ) private view returns (bool) {
        return s.statusBits & mask != 0;
    }
}
