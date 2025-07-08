// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibCodec } from "../../../../contracts/layer1/based2/libs/LibCodec.sol";
import { IInbox } from "../../../../contracts/layer1/based2/IInbox.sol";

contract LibCodecTest is Test {
    using LibCodec for IInbox.TransitionMeta;
}
