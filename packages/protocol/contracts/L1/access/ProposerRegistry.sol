// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";
import "./IProposerAccess.sol";

/// @title ProposerRegistry
/// A dummy implementation that only whitelist some trusted addresses. A real
/// implementation would only allow a single proposer address to propose a block
/// using some selection mechanism.
/// @custom:security-contact security@taiko.xyz
contract ProposerRegistry is EssentialContract, IProposerAccess {
    /// @dev Emitted when the status of a proposer is updated.
    /// @param proposer The address of the proposer whose state has updated.
    /// @param enabled If the proposer is now enabled or not.
    event ProposerUpdated(address indexed proposer, bool enabled);

    /// @notice Whitelisted proposers
    mapping(address proposer => bool enabled) public proposers;

    uint256[49] private __gap;

    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The address of the owner.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Register or unregister proposers.
    /// @param _proposers The list of proposers
    /// @param _enabled The corresponding list of the new status of the proposers
    function registerProposers(
        address[] memory _proposers,
        bool[] memory _enabled
    )
        external
        onlyOwner
    {
        require(_proposers.length == _enabled.length, "invalid input data");
        for (uint256 i = 0; i < _proposers.length; i++) {
            proposers[_proposers[i]] = _enabled[i];
            emit ProposerUpdated(_proposers[i], _enabled[i]);
        }
    }

    /// @inheritdoc IProposerAccess
    function isProposerEligible(address _proposer) external view returns (bool) {
        return proposers[_proposer];
    }
}
