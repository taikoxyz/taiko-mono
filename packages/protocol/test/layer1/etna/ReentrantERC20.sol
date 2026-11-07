// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ReentrantERC20
/// @notice An ERC-20 whose `transfer` and `transferFrom` can make one armed call before moving
/// tokens, bubbling up that call's revert.
contract ReentrantERC20 is ERC20 {
    address private _reentryTarget;
    bytes private _reentryData;

    constructor() ERC20("Reentrant", "RE") { }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    /// @dev Arms the next `transfer` or `transferFrom` to call `_target` with `_data` first.
    function armReentry(address _target, bytes calldata _data) external {
        _reentryTarget = _target;
        _reentryData = _data;
    }

    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _reenter();
        return super.transfer(_to, _amount);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    )
        public
        override
        returns (bool)
    {
        _reenter();
        return super.transferFrom(_from, _to, _amount);
    }

    /// @dev Makes the armed call, once.
    function _reenter() private {
        address target = _reentryTarget;
        if (target == address(0)) return;
        delete _reentryTarget;
        (bool ok, bytes memory ret) = target.call(_reentryData);
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }
}
