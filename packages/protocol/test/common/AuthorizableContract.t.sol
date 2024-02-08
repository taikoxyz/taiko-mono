// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "../L1/TaikoL1TestBase.sol";

/// @author Kirk Baird <kirk@sigmaprime.io>
contract TestAuthorizableContract is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        // Call the TaikoL1TestBase setUp()
        super.setUp();
    }

    function test_authorize() external {
        bytes32 bobLabel = keccak256("Bob");
        //logs
        vm.expectEmit(address(ss));
        emit AuthorizableContract.Authorized(Bob, 0, bobLabel);
        // call authorize
        ss.authorize(Bob, bobLabel);

        // validation
        assertEq(
            ss.authorizedAddresses(Bob),
            bobLabel,
            "wrong Label"
        );
        assertEq(
            ss.isAuthorizedAs(Bob, bobLabel),
            true,
            "should return true"
        );

        //stop prank
        vm.stopPrank();
    }

    function test_authorize_invalid_address() external {
        bytes32 bobLabel = keccak256("Bob");

        vm.expectRevert(AuthorizableContract.INVALID_ADDRESS.selector);
        // call authorize
        ss.authorize(address(0), bobLabel);
    }

    function test_authorize_invalid_label() external {
        bytes32 bobLabel = keccak256("Bob");

        //logs
        vm.expectEmit(address(ss));
        emit AuthorizableContract.Authorized(Bob, 0, bobLabel);

        // call authorize
        ss.authorize(Bob, bobLabel);

        // call authorize
        vm.expectRevert(AuthorizableContract.INVALID_LABEL.selector);
        ss.authorize(Bob, bobLabel);
    }

    function test_isAuthorizedAs() external {
        bytes32 bobLabel = keccak256("Bob");

        //logs
        vm.expectEmit(address(ss));
        emit AuthorizableContract.Authorized(Bob, 0, bobLabel);

        // call authorize
        ss.authorize(Bob, bobLabel);

        assertEq(
            ss.isAuthorizedAs(Bob, bobLabel),
            true,
            "should return true"
        );
        assertEq(
            ss.isAuthorizedAs(Alice, 0),
            false,
            "should return false"
        );
    }

}