// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibData } from "../../../../contracts/layer1/based2/libs/LibData.sol";
import { IInbox } from "../../../../contracts/layer1/based2/IInbox.sol";

contract LibDataTest is Test {
    using LibData for IInbox.TransitionMeta;
}
