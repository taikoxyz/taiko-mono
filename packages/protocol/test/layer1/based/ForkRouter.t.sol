// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "src/layer1/based/ForkRouter.sol";

contract Fork is EssentialContract, IFork {
    bytes32 private immutable __name;
    bool private immutable __isActive;

    constructor(bytes32 _name, bool _isActive) EssentialContract(address(0)) {
        __name = _name;
        __isActive = _isActive;
    }

    function init() external initializer {
        __Essential_init(address(0));
    }

    function name() public view returns (bytes32) {
        return __name;
    }

    function isForkActive() external view override returns (bool) {
        return __isActive;
    }
}

contract ForkFooA is EssentialContract, IFork {
    struct State {
        uint64 a;
    }

    State private _state;

    constructor() EssentialContract(address(0)) { }

    function init() external initializer {
        __Essential_init(address(0));
        _state.a = 100;
    }

    function setCounter(uint64 _a) external returns (uint64) {
        _state.a = _a;
        return _state.a;
    }

    function counter() external view returns (uint64) {
        return _state.a;
    }

    function isForkActive() external view override returns (bool) {
        return _state.a < 10;
    }
}

contract ForkFooB is EssentialContract, IFork {
    struct State {
        uint64 b;
    }

    State private _state;

    constructor() EssentialContract(address(0)) { }

    function init() external initializer {
        __Essential_init(address(0));
    }

    function setCounter(uint64 _b) external returns (uint64) {
        _state.b = _b;
        return _state.b;
    }

    function counter() external view returns (uint64) {
        return _state.b;
    }

    function isForkActive() external view override returns (bool) {
        console.log("isForkActive in ForkFooB:", _state.b);
        return _state.b >= 10;
    }
}

contract TestForkRouter is Layer1Test {
    function test_ForkManager_default_routing() public transactBy(deployer) {
        address fork1 = address(new Fork("fork1", true));

        address router = deploy({
            name: "fork_router",
            impl: address(new ForkRouter(address(0), fork1)),
            data: abi.encodeCall(Fork.init, ())
        });

        assertTrue(ForkRouter(payable(router)).isForkRouter());
        assertEq(Fork(router).name(), "fork1");

        // If we upgrade the proxy's impl to a fork, then alling isForkRouter will throw,
        // so we should never do this in production.

        Fork(router).upgradeTo(fork1);
        vm.expectRevert();
        ForkRouter(payable(router)).isForkRouter();

        address fork2 = address(new Fork("fork2", true));
        Fork(router).upgradeTo(address(new ForkRouter(fork1, fork2)));
        assertEq(Fork(router).name(), "fork2");
    }

    function test_ForkManager_routing_to_old_fork() public transactBy(deployer) {
        address fork1 = address(new Fork("fork1", false));
        address fork2 = address(new Fork("fork2", false));

        address router = deploy({
            name: "fork_router",
            impl: address(new ForkRouter(fork1, fork2)),
            data: abi.encodeCall(Fork.init, ())
        });

        assertTrue(ForkRouter(payable(router)).isForkRouter());
        assertEq(Fork(router).name(), "fork1");

        fork2 = address(new Fork("fork2", true));
        Fork(router).upgradeTo(address(new ForkRouter(fork1, fork2)));
        assertTrue(ForkRouter(payable(router)).isForkRouter());
        assertEq(Fork(router).name(), "fork2");
    }

    function test_ForkManager_readStorage() public transactBy(deployer) {
        address fork1 = address(new ForkFooA());
        address fork2 = address(new ForkFooB());

        address router = deploy({
            name: "fork_router",
            impl: address(new ForkRouter(fork1, fork2)),
            data: abi.encodeCall(Fork.init, ())
        });

        assertEq(ForkRouter(payable(router)).currentFork(), fork1);
        // assertEq(ForkFooA(router).counter(), 1);
        // assertEq(ForkFooA(router).setCounter(2), 2);
        // assertEq(ForkFooA(router).counter(), 2);
        // assertEq(ForkRouter(payable(router)).currentFork(), fork1);

        // assertEq(ForkFooA(router).setCounter(10), 10);
        // assertEq(ForkRouter(payable(router)).currentFork(), fork2);
    }
}
