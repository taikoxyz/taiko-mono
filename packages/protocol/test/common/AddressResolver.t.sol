// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../L1/TaikoL1TestBase.sol";

/// @author Kirk Baird <kirk@sigmaprime.io>
contract TestAddressResolver is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        // Call the TaikoL1TestBase setUp()
        super.setUp();
    }

    function test_resolve() external {
        assertEq(
            bridge.resolve(uint64(block.chainid), bytes32(bytes("tier_guardian")), false),
            address(gp),
            "wrong guardianVerifier address"
        );

        assertEq(
            bridge.resolve(uint64(block.chainid), bytes32(bytes("tier_sgx")), false),
            address(sv),
            " wrong sgxVerifier address"
        );
    }

    // Tests `resolve()` revert on zero address
    function test_resolve_revertZeroAddress() external {
        bytes32 name = bytes32(bytes("signal_service"));
        vm.expectRevert(
            abi.encodeWithSelector(AddressResolver.RESOLVER_ZERO_ADDR.selector, 666, name)
        );

        bridge.resolve(uint64(666), name, false);
    }

    // Tests `resolve()` successfully return zero address
    function test_resolve_returnZeroAddress() external {
        assertEq(
            bridge.resolve(uint64(123), bytes32(bytes("taiko")), true),
            address(0),
            " should return address(0)"
        );
    }
}
