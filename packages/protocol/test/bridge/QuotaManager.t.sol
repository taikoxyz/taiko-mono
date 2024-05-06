// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract QuotaManagerTest is TaikoTest {
    AddressManager public am;
    QuotaManager public qm;

    address bridge = vm.addr(0x100);

    function setUp() public {
        vm.startPrank(Alice); // The owner
        vm.deal(Alice, 100 ether);

        am = AddressManager(
            deployProxy({
                name: "address_manager",
                impl: address(new AddressManager()),
                data: abi.encodeCall(AddressManager.init, (address(0)))
            })
        );

        am.setAddress(uint64(block.chainid), LibStrings.B_BRIDGE, bridge);

        qm = QuotaManager(
            payable(
                deployProxy({
                    name: "quota_manager",
                    impl: address(new QuotaManager()),
                    data: abi.encodeCall(QuotaManager.init, (address(0), address(am), 24 hours))
                })
            )
        );

        vm.stopPrank();
    }

    function test_quota_manager_consume_configged() public {
        address Ether = address(0);
        assertEq(qm.availableQuota(Ether, 0), type(uint256).max);

        vm.expectRevert();
        qm.updateQuota(Ether, 10 ether);

        vm.prank(Alice);
        qm.updateQuota(Ether, 10 ether);
        assertEq(qm.availableQuota(address(0), 0), 10 ether);

        vm.expectRevert(AddressResolver.RESOLVER_DENIED.selector);
        qm.consumeQuota(Ether, 5 ether);

        vm.prank(bridge);
        qm.consumeQuota(Ether, 6 ether);
        assertEq(qm.availableQuota(Ether, 0), 4 ether);

        assertEq(qm.availableQuota(Ether, 3 hours), 4 ether + 10 ether * 3 / 24);

        vm.warp(block.timestamp + 3 hours);
        assertEq(qm.availableQuota(Ether, 0), 4 ether + 10 ether * 3 / 24);

        vm.warp(block.timestamp + 24 hours);
        assertEq(qm.availableQuota(Ether, 0), 10 ether);
    }

    function test_quota_manager_consume_unconfigged() public {
        address token = address(999);
        assertEq(qm.availableQuota(token, 0), type(uint256).max);

        vm.prank(bridge);
        qm.consumeQuota(token, 6 ether);
        assertEq(qm.availableQuota(token, 0), type(uint256).max);
    }
}
