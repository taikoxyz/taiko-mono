// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @dev Pins the staking contract's ABI to the selectors, event topics and block-start calldata
/// that the spec's appendix A gives, which the execution layer, the nodes and the guests build in.
contract IEtnaStakingAbiTest is CommonTest {
    function test_selectors_MatchTheSpecAbi() external pure {
        assertEq(IEtnaStaking.register.selector, bytes4(0x864274b0), "register");
        assertEq(IEtnaStaking.topUp.selector, bytes4(0xde643a71), "topUp");
        assertEq(IEtnaStaking.requestExit.selector, bytes4(0x721c6513), "requestExit");
        assertEq(IEtnaStaking.withdraw.selector, bytes4(0x00f714ce), "withdraw");
        assertEq(IEtnaStaking.slashDoubleSign.selector, bytes4(0xd61617a4), "slashDoubleSign");
        assertEq(IEtnaStaking.forfeit.selector, bytes4(0x7b41461f), "forfeit");
        assertEq(IEtnaStaking.onBlockStart.selector, bytes4(0xea987592), "onBlockStart");
        assertEq(IEtnaStaking.bondForKey.selector, bytes4(0x830dc3a1), "bondForKey");
        assertEq(IEtnaStaking.seatOfBond.selector, bytes4(0x7b81a4dc), "seatOfBond");
        assertEq(IEtnaStaking.bondInSeat.selector, bytes4(0xd0b5360d), "bondInSeat");
        assertEq(IEtnaStaking.snapshot.selector, bytes4(0x9711715a), "snapshot");
        assertEq(IEtnaStaking.registerDigest.selector, bytes4(0x049785d3), "registerDigest");
    }

    function test_eventTopics_MatchTheSpec() external pure {
        assertEq(
            IEtnaStaking.TopUpDeposited.selector,
            0x06a2187e7ae93aae0a9ff5c976b126441fdcc2c16afd1274e9ba793336f179ab,
            "TopUpDeposited"
        );
        assertEq(
            IEtnaStaking.Forfeited.selector,
            0xfa0800b34e880af94586f918c482b017b7cb8d550255ba57a432bc218dbdfc6b,
            "Forfeited"
        );
    }

    /// @dev The block-start calldata is the selector followed by the two arguments' standard ABI
    /// words, 68 bytes in all.
    function test_onBlockStartCalldata_IsTheStandardEncoding() external pure {
        bytes memory data =
            abi.encodeCall(IEtnaStaking.onBlockStart, (uint48(1), uint128(2 ** 127 + 1)));
        assertEq(data.length, 68, "length");
        assertEq(
            data, abi.encodePacked(bytes4(0xea987592), uint256(1), uint256(2 ** 127 + 1)), "data"
        );
    }
}
