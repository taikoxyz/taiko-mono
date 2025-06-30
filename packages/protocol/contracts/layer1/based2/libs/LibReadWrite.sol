// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

library LibReadWrite {
    struct RW {
        // reads
        function(I.Config memory, bytes32) view returns (bool) isSignalSent;
        function(I.Config memory, bytes32, uint256) view returns (bytes32, bool)
            loadTransitionMetaHash;
        function(uint256) view returns (bytes32) getBlobHash;
        // writes
        function(address, address, address, uint256) transferFee;
        function(address, uint256) creditBond;
        function(I.Config memory, address, uint256) debitBond;
        function(I.Config memory, uint256, bytes32) saveBatchMetaHash;
        function(I.Config memory, uint48, bytes32, bytes32) returns (bool) saveTransition;
        function(I.Config memory, uint64, bytes32) syncChainData;
    }
}
