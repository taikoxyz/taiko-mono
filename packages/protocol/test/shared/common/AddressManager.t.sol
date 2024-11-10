// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";

// /// @author Kirk Baird <kirk@sigmaprime.io>
// contract TestAddressManager is CommonTest{
//     function deployTaikoL1() internal override returns (TaikoL1) {
//         return
//             TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: ""
// })));
//     }

//     function setUp() public override {
//         // Call the TaikoL1TestBase setUp()
//         super.setUp();
//     }

//     function test_setAddress() external {
//         uint64 chainid = 1;
//         bytes32 name = bytes32(bytes("Bob"));
//         address newAddress = Bob;
//         // logs
//         vm.expectEmit(address(resolver));
//         emit AddressManager.AddressSet(chainid, name, newAddress, address(0));

//         // call `setAddress()`
//         resolver.registerAddress(chainid, name, newAddress);

//         // validation
//         assertEq(resolver.getAddress(chainid, name), Bob, "should return Bob address");
//     }

//     function test_setAddress_callerNotOwner() external {
//         vm.startPrank(Alice);

//         uint64 chainid = 1;
//         bytes32 name = bytes32(bytes("Bob"));
//         address newAddress = Bob;

//         // call `setAddress()`
//         vm.expectRevert("Ownable: caller is not the owner");
//         resolver.registerAddress(chainid, name, newAddress);
//     }

//     function test_getAddress() external {
//         assertEq(
//             resolver.getAddress(ethereumChainId, bytes32(bytes("taiko"))),
//             address(L1),
//             "expected address should be TaikoL1"
//         );
//     }
// }
