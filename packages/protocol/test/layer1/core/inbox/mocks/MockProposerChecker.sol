// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";

contract MockProposerChecker is IProposerChecker {
    function checkProposer(address, bytes calldata) external pure returns (uint48) {
        return 0;
    }
}
