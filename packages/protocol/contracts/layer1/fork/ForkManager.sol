// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title ForkManager
/// @custom:security-contact security@taiko.xyz
/// @notice This contract serves as a base contract for managing up to two forks within the Taiko
/// protocol. By default, all function calls are routed to the newFork address.
/// Sub-contracts should override the shouldRouteToOldFork function to route specific function calls
/// to the old fork address.
/// These sub-contracts should be placed between a proxy and the actual fork implementations. When
/// calling upgradeTo, the proxy should always upgrade to a new ForkManager implementation, not an
/// actual fork implementation.
/// It is strongly advised to name functions differently for the same functionality across the two
/// forks, as it is not possible to route the same function to two different forks.
///
///                         +--> newFork
/// PROXY -> FORK_MANAGER --|
///                         +--> oldFork

contract ForkManager is UUPSUpgradeable, Ownable2StepUpgradeable {
    address public immutable oldFork;
    address public immutable newFork;

    error ForkAddressIsZero();
    error InvalidParams();

    constructor(address _oldFork, address _currFork) {
        require(_currFork != address(0) && _currFork != _oldFork, InvalidParams());
        oldFork = _oldFork;
        newFork = _currFork;
    }

    fallback() external payable virtual {
        _fallback();
    }

    receive() external payable virtual {
        _fallback();
    }

    function isForkManager() public pure returns (bool) {
        return true;
    }

    function _fallback() internal virtual {
        address fork = shouldRouteToOldFork(msg.sig) ? oldFork : newFork;
        require(fork != address(0), ForkAddressIsZero());

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

    /// @notice Determines if the call should be routed to the old fork.
    /// @dev This function is intended to be overridden in derived contracts to provide custom
    /// routing logic.
    /// @param  _selector The function selector of the call.
    /// @return A boolean value indicating whether the call should be routed to the old fork.
    function shouldRouteToOldFork(bytes4 _selector) internal pure virtual returns (bool) { }
}
