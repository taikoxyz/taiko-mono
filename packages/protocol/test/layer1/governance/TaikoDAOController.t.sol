// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "src/layer1/governance/TaikoDAOController.sol";

contract DummyContract {
    function someFunction() public pure returns (string memory) {
        return "someFunction";
    }
}

contract DummyEssentialContract is EssentialContract {
    constructor() EssentialContract(address(0)) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }
}

contract TestTaikoDAOController is Layer1Test {
    TaikoDAOController internal daoController;
    address owner = Alice;
    address newOwner = Bob;
    address target = address(new DummyContract());
    bytes data = abi.encodeWithSignature("someFunction()");
    DummyEssentialContract dummyEssentialContract;

    function setUpOnEthereum() internal override {
        vm.deal(Alice, 1 ether);
        vm.deal(Carol, 1 ether);

        super.setUpOnEthereum();
        daoController = TaikoDAOController(
            payable(
                deploy({
                    name: "TaikoDAOController",
                    impl: address(new TaikoDAOController()),
                    data: abi.encodeCall(TaikoDAOController.init, (owner))
                })
            )
        );

        dummyEssentialContract = DummyEssentialContract(
            deploy({
                name: "DummyEssentialContract",
                impl: address(new DummyEssentialContract()),
                data: abi.encodeCall(DummyEssentialContract.init, (Bob))
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
        bytes memory result = daoController.execute(target, 0, data);
        assertEq(result, abi.encode("someFunction"), "Forwarded call should return correct data");
        vm.stopPrank();
    }

    function test_TaikoDAOController_executeNotOwner() public {
        vm.startPrank(newOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        daoController.execute(target, 0, data);
        vm.stopPrank();
    }

    function test_TaikoDAOController_executeToZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(TaikoDAOController.InvalidTarget.selector);
        daoController.execute(address(0), 0, data);
    }

    function test_TaikoDAOController_executeToOwner() public {
        vm.startPrank(owner);
        vm.expectRevert(TaikoDAOController.InvalidTarget.selector);
        daoController.execute(owner, 0, data);
    }

    function test_TaikoDAOController_acceptOwnershipOf() public {
        vm.startPrank(Bob);
        dummyEssentialContract.transferOwnership(address(daoController));
        assertEq(dummyEssentialContract.owner(), Bob);

        daoController.acceptOwnershipOf(address(dummyEssentialContract));
        assertEq(dummyEssentialContract.owner(), address(daoController));
    }

    function test_TaikoDAOController_receiveEther() public {
        vm.prank(Carol);
        (bool success,) = payable(address(daoController)).call{ value: 0.1 ether }("");
        require(success);
        assertEq(address(daoController).balance, 0.1 ether);

        vm.prank(owner);
        daoController.execute{ value: 0.2 ether }(address(David), 0.3 ether, "");

        assertEq(address(daoController).balance, 0);
        assertEq(address(David).balance, 0.3 ether);
    }
}
