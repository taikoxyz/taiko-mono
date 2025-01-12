// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "src/layer1/based/ForkManager.sol";

contract Fork is EssentialContract, IFork {
    bytes32 private immutable __name;
    bool private immutable __isActive;

    constructor(bytes32 _name, bool _isActive) {
        __name = _name;
        __isActive = _isActive;
    }

    function init() external initializer {
        __Essential_init(msg.sender);
    }

    function name() public view returns (bytes32) {
        return __name;
    }

    function isForkActive() external view override returns (bool) {
        return __isActive;
    }
}

contract TestForkManager is Layer1Test {
    function test_ForkManager_default_routing() public transactBy(deployer) {
        address fork1 = address(new Fork("fork1", true));

        address proxy = deploy({
            name: "main_proxy",
            impl: address(new ForkManager(address(0), fork1)),
            data: abi.encodeCall(Fork.init, ())
        });

        assertTrue(ForkManager(payable(proxy)).isForkManager());
        assertEq(Fork(proxy).name(), "fork1");

        // If we upgrade the proxy's impl to a fork, then alling isForkManager will throw,
        // so we should never do this in production.
        address fork2 = address(new Fork("fork2", true));
        Fork(proxy).upgradeTo(fork2);
        vm.expectRevert();
        ForkManager(payable(proxy)).isForkManager();

        Fork(proxy).upgradeTo(address(new ForkManager(fork1, fork2)));
        assertEq(Fork(proxy).name(), "fork2");
    }

    function test_ForkManager_routing_to_old_fork() public transactBy(deployer) {
        address fork1 = address(new Fork("fork1", false));
        address fork2 = address(new Fork("fork2", false));

        address proxy = deploy({
            name: "main_proxy",
            impl: address(new ForkManager(fork1, fork2)),
            data: abi.encodeCall(Fork.init, ())
        });

        assertTrue(ForkManager(payable(proxy)).isForkManager());
        assertEq(Fork(proxy).name(), "fork1");

        fork2 = address(new Fork("fork2", true));
        Fork(proxy).upgradeTo(address(new ForkManager(fork1, fork2)));
        assertTrue(ForkManager(payable(proxy)).isForkManager());
        assertEq(Fork(proxy).name(), "fork2");
    }
}
