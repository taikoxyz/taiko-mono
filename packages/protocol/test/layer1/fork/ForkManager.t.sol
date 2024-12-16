// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "src/layer1/fork/ForkManager.sol";

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

contract ForkManager_RouteToOldFork is ForkManager {
    constructor(address _fork1, address _fork2) ForkManager(_fork1, _fork2) { }

    function shouldRouteToOldFork(bytes4 _selector) internal pure override returns (bool) {
        return _selector == Fork.name.selector;
    }
}

contract TestForkManager is Layer1Test {
    address fork1 = address(new Fork("fork1"));
    address fork2 = address(new Fork("fork2"));

    function test_ForkManager_default_routing() public transactBy(deployer) {
        address proxy = deploy({
            name: "main_proxy",
            impl: address(new ForkManager(address(0), fork1)),
            data: abi.encodeCall(Fork.init, ())
        });

        assertTrue(ForkManager(payable(proxy)).isForkManager());
        assertEq(Fork(proxy).name(), "fork1");

        // If we upgrade the proxy's impl to a fork, then alling isForkManager will throw,
        // so we should never do this in production.


        Fork(proxy).upgradeTo(fork2);
        vm.expectRevert();
        ForkManager(payable(proxy)).isForkManager();

        Fork(proxy).upgradeTo(address(new ForkManager(fork1, fork2)));
        assertEq(Fork(proxy).name(), "fork2");
    }

    function test_ForkManager_routing_to_old_fork() public transactBy(deployer) {
        address proxy = deploy({
            name: "main_proxy",
            impl: address(new ForkManager_RouteToOldFork(fork1, fork2)),
            data: abi.encodeCall(Fork.init, ())
        });

        assertTrue(ForkManager(payable(proxy)).isForkManager());
        assertEq(Fork(proxy).name(), "fork1");

        Fork(proxy).upgradeTo(address(new ForkManager(fork1, fork2)));
        assertTrue(ForkManager(payable(proxy)).isForkManager());
        assertEq(Fork(proxy).name(), "fork2");
    }
}
