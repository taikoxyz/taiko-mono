// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/thirdparty/AddressManager.sol";
import "../contracts/L1/TaikoL1.sol";

contract TaikoL1Test is Test {
    TaikoL1 public L1;

    AddressManager public addressManager;
    bytes32 public genesisBlockHash;

    function setUp() public {
        addressManager = new AddressManager();
        addressManager.init();

        uint256 feeBase = 1E18;
        L1 = new TaikoL1();
        L1.init(address(addressManager), genesisBlockHash, feeBase);
    }

    function testIncrement() public {
    }

    function testSetNumber(uint256 x) public {
        // assertEq(counter.number(), x);
    }
}