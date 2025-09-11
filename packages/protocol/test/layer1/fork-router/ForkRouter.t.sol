// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "src/layer1/fork-router/ForkRouter.sol";

contract Fork is EssentialContract {
    bytes32 private immutable __name;

    constructor(bytes32 _name) {
        __name = _name;
    }

    function init() external initializer {
        __Essential_init(msg.sender);
    }

    function name() public view returns (bytes32) {
        return __name;
    }
}

contract ForkRouter_RouteToOldFork is ForkRouter {
    constructor(address _fork1, address _fork2) ForkRouter(_fork1, _fork2) { }

    function shouldRouteToOldFork(bytes4 _selector) public pure override returns (bool) {
        return _selector == Fork.name.selector;
    }
}

contract TestForkRouter is Layer1Test {
    address fork1 = address(new Fork("fork1"));
    address fork2 = address(new Fork("fork2"));

    function test_ForkRouter_default_routing() public transactBy(deployer) {
        address proxy = deploy({
            name: "main_proxy",
            impl: address(new ForkRouter(address(0), fork1)),
            data: abi.encodeCall(Fork.init, ())
        });

        assertEq(Fork(proxy).name(), "fork1");

        Fork(proxy).upgradeTo(fork2);
        Fork(proxy).upgradeTo(address(new ForkRouter(fork1, fork2)));
        assertEq(Fork(proxy).name(), "fork2");
        Fork(proxy).upgradeTo(address(new ForkRouter(fork2, fork1)));
        assertEq(Fork(proxy).name(), "fork1");
    }

    function test_ForkRouter_routing_to_old_fork() public transactBy(deployer) {
        address proxy = deploy({
            name: "main_proxy",
            impl: address(new ForkRouter_RouteToOldFork(fork1, fork2)),
            data: abi.encodeCall(Fork.init, ())
        });

        assertEq(Fork(proxy).name(), "fork1");
        Fork(proxy).upgradeTo(address(new ForkRouter(fork1, fork2)));
        assertEq(Fork(proxy).name(), "fork2");
    }
}
