// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";
import "../../contracts/libs/LibAddress.sol";

contract CalldataReceiver {
    // Returns success
    function returnSuccess() public pure returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool result) {
        if (interfaceId == 0x10101010) {
            result = true;
        }
    }

    // Reverts
    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }
}

/// @notice The reason we call LibAddress.sendEther this way is - and not directly inside of a
/// test_sendEther() because this way the coverage adds up if you call functions against initiated
/// contracts, so basically it is a workaround making the library test 'count' towards the coverage.
/// @dev The EtherSenderContract in live environment is the Bridge.
contract EtherSenderContract {
    function sendEther(
        address _to,
        uint256 _amount,
        uint256 _gasLimit,
        bytes memory _calldata
    )
        public
        returns (bool success_)
    {
        success_ = LibAddress.sendEther(_to, _amount, _gasLimit, _calldata);
    }

    function sendEtherAndVerify(address _to, uint256 _amount, uint256 _gasLimit) public {
        LibAddress.sendEtherAndVerify(_to, _amount, _gasLimit);
    }

    function sendEtherAndVerify(address _to, uint256 _amount) public {
        LibAddress.sendEtherAndVerify(_to, _amount);
    }

    function supportsInterface(
        address _addr,
        bytes4 _interfaceId
    )
        public
        view
        returns (bool result)
    {
        return LibAddress.supportsInterface(_addr, _interfaceId);
    }
}

contract TestLibAddress is TaikoTest {
    EtherSenderContract bridge;
    CalldataReceiver calledContract;

    function setUp() public virtual {
        bridge = new EtherSenderContract();
        vm.deal(address(bridge), 1 ether);

        calledContract = new CalldataReceiver();
    }

    function test_sendEther() public {
        uint256 balanceBefore = Alice.balance;
        bridge.sendEther((Alice), 0.5 ether, 2300, "");
        assertEq(Alice.balance, balanceBefore + 0.5 ether);

        // Cannot send to address(0)
        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        bridge.sendEther(address(0), 0.5 ether, 2300, "");
    }

    function test_sendEther_with_calldata() public {
        bytes memory functionCalldata = abi.encodeCall(CalldataReceiver.returnSuccess, ());

        bool success = bridge.sendEther(address(calledContract), 0, 230_000, functionCalldata);

        assertEq(success, true);

        // No input argument so it will fall to the fallback.
        bytes memory wrongfunctionCalldata =
            abi.encodeWithSelector(IERC165Upgradeable.supportsInterface.selector, 10);
        success = bridge.sendEther(address(calledContract), 0, 230_000, wrongfunctionCalldata);

        assertEq(success, false);
    }

    function test_sendEtherAndVerify() public {
        uint256 balanceBefore = Alice.balance;
        bridge.sendEtherAndVerify(Alice, 0.5 ether, 2300);
        assertEq(Alice.balance, balanceBefore + 0.5 ether);

        // Send 0 ether is also possible
        bridge.sendEtherAndVerify(Alice, 0, 2300);

        // If sending fails, call reverts
        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        bridge.sendEtherAndVerify(address(calledContract), 0.1 ether, 2300);

        //Call sendEtherAndVerify without the gasLimit
        bridge.sendEtherAndVerify(Alice, 0.5 ether);
        assertEq(Alice.balance, balanceBefore + 1 ether);
    }

    function test_supportsInterface() public {
        bool doesSupport = bridge.supportsInterface(Alice, 0x10101010);

        assertEq(doesSupport, false);

        doesSupport = bridge.supportsInterface(address(bridge), 0x10101010);

        assertEq(doesSupport, false);

        doesSupport = bridge.supportsInterface(address(calledContract), 0x10101010);

        assertEq(doesSupport, true);
    }
}
