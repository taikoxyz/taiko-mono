// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "src/layer1/governance/TaikoDAOController.sol";

contract DummyContract {
    function someFunction() public pure returns (string memory) {
        return "someFunction";
    }
}

contract TestTaikoDAOController is Layer1Test {
    TaikoDAOController internal daoController;
    address owner = address(0x123);
    address newOwner = address(0x456);
    address target = address(new DummyContract());
    bytes data = abi.encodeWithSignature("someFunction()");

    function setUpOnEthereum() internal override {
        super.setUpOnEthereum();
        daoController = TaikoDAOController(
            deploy({
                name: "TaikoDAOController",
                impl: address(new TaikoDAOController()),
                data: abi.encodeCall(TaikoDAOController.init, (owner))
            })
        );
    }

    function test_TaikoDAOController_InitialOwner() public view {
        assertEq(daoController.owner(), owner, "Owner should be set correctly");
    }

    function test_TaikoDAOController_TransferOwnership() public {
        vm.prank(owner);
        daoController.transferOwnership(newOwner);

        vm.prank(newOwner);
        daoController.acceptOwnership();

        assertEq(daoController.owner(), newOwner, "Ownership should be transferred");
    }

    function test_TaikoDAOController_execute() public {
        vm.startPrank(owner);
        (bool success,) = target.call(data);
        require(success);
        bytes memory result = daoController.execute(target, data);
        assertEq(result, abi.encode("someFunction"), "Forwarded call should return correct data");
        vm.stopPrank();
    }

    function test_TaikoDAOController_executeNotOwner() public {
        vm.startPrank(newOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        daoController.execute(target, data);
        vm.stopPrank();
    }

    function test_TaikoDAOController_executeToZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(TaikoDAOController.InvalidTarget.selector);
        daoController.execute(address(0), data);
    }

    function test_TaikoDAOController_executeToSameAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(TaikoDAOController.InvalidTarget.selector);
        daoController.execute(address(daoController), data);
    }

    function test_TaikoDAOController_executeToOwner() public {
        vm.startPrank(owner);
        vm.expectRevert(TaikoDAOController.InvalidTarget.selector);
        daoController.execute(owner, data);
    }

    function test_TaikoDAOController_executeToContractWithoutCode() public {
        vm.startPrank(owner);
        vm.expectRevert(TaikoDAOController.InvalidTarget.selector);
        daoController.execute(address(0x999), data);
    }
}
