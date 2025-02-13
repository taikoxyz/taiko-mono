// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title ForkRouter
/// @custom:security-contact security@taiko.xyz
/// @notice This contract routes calls to the current fork.
///
///                         +--> newFork
/// PROXY -> FORK_ROUTER--|
///                         +--> oldFork
contract ForkRouter is UUPSUpgradeable, Ownable2StepUpgradeable {
    address public immutable oldFork;
    address public immutable newFork;

    error InvalidParams();
    error ZeroForkAddress();

    constructor(address _oldFork, address _newFork) {
        require(_newFork != address(0), InvalidParams());
        require(_newFork != _oldFork, InvalidParams());

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

    /// @notice Returns true if a function should be routed to the old fork
    /// @dev This function should be overridden by the implementation contract
    function shouldRouteToOldFork(bytes4) public pure virtual returns (bool) {
        return false;
    }

    function _fallback() internal virtual {
        address fork = shouldRouteToOldFork(msg.sig) ? oldFork : newFork;
        require(fork != address(0), ZeroForkAddress());

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
