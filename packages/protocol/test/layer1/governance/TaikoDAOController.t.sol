// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/layer1/mainnet/MainnetDAOController.sol";
import "test/shared/CommonTest.sol";

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

contract TestMainnetDAOController is CommonTest {
    MainnetDAOController internal daoController;
    address owner = Alice;
    address newOwner = Bob;
    address target = address(new DummyContract());
    bytes data = abi.encodeWithSignature("someFunction()");
    DummyEssentialContract dummyEssentialContract;

    function setUpOnEthereum() internal override {
        vm.deal(Alice, 1 ether);
        vm.deal(Carol, 1 ether);

        super.setUpOnEthereum();
        daoController = MainnetDAOController(
            payable(deploy({
                    name: "MainnetDAOController",
                    impl: address(new MainnetDAOController()),
                    data: abi.encodeCall(MainnetDAOController.init, (owner))
                }))
        );

        dummyEssentialContract = DummyEssentialContract(
            deploy({
                name: "DummyEssentialContract",
                impl: address(new DummyEssentialContract()),
                data: abi.encodeCall(DummyEssentialContract.init, (Bob))
            })
        );
    }

    function test_MainnetDAOController_InitialOwner() public view {
        assertEq(daoController.owner(), owner, "Owner should be set correctly");
    }

    function test_MainnetDAOController_execute() public {
        vm.startPrank(owner);
        (bool success,) = target.call(data);
        require(success);

        Controller.Action[] memory actions = new Controller.Action[](1);
        actions[0] = Controller.Action({ target: target, value: 0, data: data });
        bytes[] memory results = daoController.execute(abi.encode(actions));

        assertEq(
            results[0], abi.encode("someFunction"), "Forwarded call should return correct data"
        );
        vm.stopPrank();
    }

    function test_MainnetDAOController_executeNotOwner() public {
        Controller.Action[] memory actions = new Controller.Action[](1);
        actions[0] = Controller.Action({ target: target, value: 0, data: data });

        vm.startPrank(newOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        daoController.execute(abi.encode(actions));
        vm.stopPrank();
    }

    function test_MainnetDAOController_acceptOwnershipOf() public {
        vm.startPrank(Bob);
        dummyEssentialContract.transferOwnership(address(daoController));
        assertEq(dummyEssentialContract.owner(), Bob);

        daoController.acceptOwnershipOf(address(dummyEssentialContract));
        assertEq(dummyEssentialContract.owner(), address(daoController));
    }

    function test_MainnetDAOController_receiveAndSendEther() public {
        vm.prank(Carol);
        (bool success,) = payable(address(daoController)).call{ value: 0.1 ether }("");
        require(success);
        assertEq(address(daoController).balance, 0.1 ether);

        vm.prank(owner);
        Controller.Action[] memory actions = new Controller.Action[](2);
        actions[0] = Controller.Action({ target: address(David), value: 0.01 ether, data: "" });

        actions[1] = Controller.Action({ target: address(Frank), value: 0.02 ether, data: "" });
        daoController.execute(abi.encode(actions));

        assertEq(address(daoController).balance, 0.07 ether);
        assertEq(address(David).balance, 0.01 ether);
        assertEq(address(Frank).balance, 0.02 ether);
    }

    function test_MainnetDAOController_transferERC20() public {
        IERC20 erc20 = new MyERC20(address(daoController), 1000 ether);
        assertEq(erc20.balanceOf(address(daoController)), 1000 ether);

        vm.prank(owner);
        Controller.Action[] memory actions = new Controller.Action[](1);
        actions[0] = Controller.Action({
            target: address(erc20),
            value: 0,
            data: abi.encodeWithSignature("transfer(address,uint256)", address(David), 100 ether)
        });
        daoController.execute(abi.encode(actions));
        assertEq(erc20.balanceOf(address(David)), 100 ether);
        assertEq(erc20.balanceOf(address(daoController)), 900 ether);
    }
}
