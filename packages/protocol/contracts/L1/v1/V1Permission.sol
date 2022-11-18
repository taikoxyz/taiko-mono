// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../libs/LibConstants.sol";
import "../LibData.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Permission {
    function canProposeBlock(
        LibData.State storage s,
        address addr
    ) public view returns (bool) {
        // return
        // LibConstants.TAIKO_PROPOSE_PERMISSIONLESS ||
        // s.permittedProposers[addr];
    }

    function canProveBlock(
        LibData.State storage s,
        address addr
    ) public pure returns (bool) {
        // return
        // LibConstants.TAIKO_PROVER_PERMISSIONLESS || s.permittedProvers[addr];
    }
}
