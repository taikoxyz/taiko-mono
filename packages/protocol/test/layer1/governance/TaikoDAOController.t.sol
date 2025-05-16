// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/layer1/governance/TaikoDAOController.sol";
import "../Layer1Test.sol";

contract DummyContract {
    function someFunction() public pure returns (string memory) {
        return "someFunction";
    }
}

contract DummyEssentialContract is EssentialContract {
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }
}

contract MyERC20 is ERC20 {
    constructor(address owner, uint256 balance) ERC20("MyERC20", "MyERC20") {
        _mint(owner, balance);
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

        TaikoDAOController.Call[] memory calls = new TaikoDAOController.Call[](1);
        calls[0] = TaikoDAOController.Call({ target: target, value: 0, data: data });
        bytes[] memory results = daoController.execute(calls);

        assertEq(
            results[0], abi.encode("someFunction"), "Forwarded call should return correct data"
        );
        vm.stopPrank();
    }

    function test_TaikoDAOController_executeNotOwner() public {
        TaikoDAOController.Call[] memory calls = new TaikoDAOController.Call[](1);
        calls[0] = TaikoDAOController.Call({ target: target, value: 0, data: data });

        vm.startPrank(newOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        daoController.execute(calls);
        vm.stopPrank();
    }

    function test_TaikoDAOController_executeToOwner() public {
        TaikoDAOController.Call[] memory calls = new TaikoDAOController.Call[](1);
        calls[0] = TaikoDAOController.Call({ target: owner, value: 0, data: data });

        vm.startPrank(owner);
        vm.expectRevert(TaikoDAOController.InvalidTarget.selector);
        daoController.execute(calls);
    }

    function test_TaikoDAOController_acceptOwnershipOf() public {
        vm.startPrank(Bob);
        dummyEssentialContract.transferOwnership(address(daoController));
        assertEq(dummyEssentialContract.owner(), Bob);

        daoController.acceptOwnershipOf(address(dummyEssentialContract));
        assertEq(dummyEssentialContract.owner(), address(daoController));
    }

    function test_TaikoDAOController_receiveAndSendEther() public {
        vm.prank(Carol);
        (bool success,) = payable(address(daoController)).call{ value: 0.1 ether }("");
        require(success);
        assertEq(address(daoController).balance, 0.1 ether);

        vm.prank(owner);
        TaikoDAOController.Call[] memory calls = new TaikoDAOController.Call[](2);
        calls[0] = TaikoDAOController.Call({ target: address(David), value: 0.01 ether, data: "" });

        calls[1] = TaikoDAOController.Call({ target: address(Frank), value: 0.02 ether, data: "" });
        daoController.execute(calls);

        assertEq(address(daoController).balance, 0.07 ether);
        assertEq(address(David).balance, 0.01 ether);
        assertEq(address(Frank).balance, 0.02 ether);
    }

    function test_TaikoDAOController_transferERC20() public {
        IERC20 erc20 = new MyERC20(address(daoController), 1000 ether);
        assertEq(erc20.balanceOf(address(daoController)), 1000 ether);

        vm.prank(owner);
        TaikoDAOController.Call[] memory calls = new TaikoDAOController.Call[](1);
        calls[0] = TaikoDAOController.Call({
            target: address(erc20),
            value: 0,
            data: abi.encodeWithSignature("transfer(address,uint256)", address(David), 100 ether)
        });
        daoController.execute(calls);
        assertEq(erc20.balanceOf(address(David)), 100 ether);
        assertEq(erc20.balanceOf(address(daoController)), 900 ether);
    }
}
