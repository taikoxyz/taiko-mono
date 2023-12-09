// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../TaikoTest.sol";

contract CrossChainOwnedContract is CrossChainOwned {
    uint256 public counter;

    function increment() external virtual onlyOwner {
        counter += 1;
    }

    function init(address addressManager) external initializer {
        __CrossChainOwned_init(addressManager, 12_345);
    }

    function _isSignalReceived(
        bytes32, /*signal*/
        bytes calldata /*proof*/
    )
        internal
        pure
        override
        returns (bool)
    {
        return true;
    }
}

contract CrossChainOwnedContract2 is CrossChainOwnedContract {
    function increment() external override onlyOwner {
        counter -= 1;
    }
}

contract TestCrossChainOwned is TaikoTest {
    CrossChainOwnedContract public xchainowned;

    function setUp() public {
        address addressManager = deployProxy({
            name: "address_manager",
            impl: address(new AddressManager()),
            data: abi.encodeCall(AddressManager.init, ())
        });
        xchainowned = CrossChainOwnedContract(
            deployProxy({
                name: "contract",
                impl: address(new CrossChainOwnedContract()),
                data: abi.encodeCall(CrossChainOwnedContract.init, (addressManager))
            })
        );
    }

    function test_xchainowned_ower_cannot_be_msgsender() public {
        vm.startPrank(xchainowned.owner());
        vm.expectRevert(CrossChainOwned.NOT_CALLABLE.selector);
        xchainowned.increment();
        vm.stopPrank();
    }

    function test_xchainowned_exec_tx() public {
        bytes memory proof = "";
        bytes memory data = abi.encodeCall(xchainowned.increment, ());

        assertEq(xchainowned.counter(), 0);
        xchainowned.executeApprovedTransaction(data, proof);
        xchainowned.executeApprovedTransaction(data, proof);
        assertEq(xchainowned.counter(), 2);
    }

    function test_xchainowned_exec_upgrade() public {
        bytes memory proof = "";

        bytes memory incrementCall = abi.encodeCall(xchainowned.increment, ());
        bytes memory upgradetoCall =
            abi.encodeCall(xchainowned.upgradeTo, (address(new CrossChainOwnedContract2())));

        assertEq(xchainowned.counter(), 0);
        xchainowned.executeApprovedTransaction(incrementCall, proof);
        assertEq(xchainowned.counter(), 1);

        xchainowned.executeApprovedTransaction(upgradetoCall, proof);
        assertEq(xchainowned.counter(), 1);

        xchainowned.executeApprovedTransaction(incrementCall, proof);
        assertEq(xchainowned.counter(), 0);
    }
}
