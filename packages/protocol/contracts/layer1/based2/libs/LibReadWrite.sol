// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

library LibReadWrite {
    struct RW {
        // reads
        function(I.Config memory, bytes32) view returns (bool) isSignalSent;
        function(uint256) view returns (bytes32) getBlobHash;
        // writes
        function(address, address, address, uint256) transferFee;
        function(address, uint256) creditBond;
        function(I.Config memory, address, uint256) debitBond;
        function(I.Config memory, uint64, bytes32) syncChainData;
    }
}
