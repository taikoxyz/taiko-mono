// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CompareGasTest.sol";

abstract contract Base {
    uint256 internal x;

    event SetX(uint256 x);

    function setX(uint256 _x) external virtual { }
}

contract Foo is Base {
    function setX(uint256 _x) external override {
        x = _x;
        emit SetX(_x);
    }
}

contract Bar is Base {
    function setX(uint256 _x) external override {
        a(_x, _setX);
    }

    function a(uint256 _x, function(uint) _setFunc) internal {
        _setFunc(_x);
    }

    function _setX(uint256 _x) private {
        x = _x;
        emit SetX(_x);
    }
}

contract FunctionPointerGassTest is CompareGasTest {
    Foo foo = new Foo();
    Bar bar = new Bar();

    function oldApproach() public {
        foo.setX(1234);
    }

    function newApproach() public {
        bar.setX(1234);
    }

    function test_FunctionPointerGas() external {
        measureGas("no pointer", oldApproach, "with pointer", newApproach);
    }
}
