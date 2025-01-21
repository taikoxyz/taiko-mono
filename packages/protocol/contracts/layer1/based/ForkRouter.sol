// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import "./IFork.sol";

/// @title ForkRouter
/// @custom:security-contact security@taiko.xyz
/// @notice This contract routes calls to the current fork.
///
///                         +--> newFork
/// PROXY -> FORK_MANAGER --|
///                         +--> oldFork
contract ForkRouter is UUPSUpgradeable, Ownable2StepUpgradeable {
    address public immutable oldFork;
    address public immutable newFork;

    error InvalidParams();
    error NewForkNotActive();
    error ZeroAddress();

    constructor(address _oldFork, address _newFork) {
        require(_newFork != address(0) && _newFork != _oldFork, InvalidParams());
        require(_oldFork != address(0) || IFork(_newFork).isForkActive(), NewForkNotActive());
        oldFork = _oldFork;
        newFork = _newFork;
        _disableInitializers();
    }

    fallback() external payable virtual {
        _fallback();
    }

    receive() external payable virtual {
        _fallback();
    }

    function currentFork() public view returns (address) {
        return IFork(newFork).isForkActive() ? newFork : oldFork;
    }

    function isForkRouter() public pure returns (bool) {
        return true;
    }

    function _fallback() internal virtual {
        address fork = currentFork();
        require(fork != address(0), ZeroAddress());

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), fork, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
