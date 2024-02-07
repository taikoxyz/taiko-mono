pragma solidity 0.8.24;

import "../L1/TaikoL1TestBase.sol";

contract TestAddressManager is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        // Call the TaikoL1TestBase setUp()
        super.setUp();
    }

    function test_setAddress() public {
        uint64 chainid = 1;
        bytes32 name = bytes32(bytes("Bob"));
        address newAddress = Bob;
        // logs
        vm.expectEmit(address(addressManager));
        emit AddressManager.AddressSet(chainid, name, newAddress, address(0));

        // call `setAddress()`
        addressManager.setAddress(chainid, name, newAddress);

        // validation
        assertEq(
            addressManager.getAddress(chainid, name),
            Bob,
            "should return Bob address"
        );
    }

    function test_setAddress_callerNotOwner() public {
        vm.startPrank(Alice);

        uint64 chainid = 1;
        bytes32 name = bytes32(bytes("Bob"));
        address newAddress = Bob;

        // call `setAddress()`
        vm.expectRevert("Ownable: caller is not the owner");
        addressManager.setAddress(chainid, name, newAddress);
    }

    function test_getAddress() public {
        assertEq(
            addressManager.getAddress(uint64(block.chainid), bytes32(bytes("taiko"))),
            address(L1),
            "expected address should be TaikoL1"
        );
    }

}