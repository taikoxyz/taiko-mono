// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import
    "@openzeppelin/contracts-upgradeable/governance/compatibility/GovernorCompatibilityBravoUpgradeable.sol";
import
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title TaikoGovernor
/// @custom:security-contact security@taiko.xyz
contract TaikoGovernor is
    Ownable2StepUpgradeable,
    GovernorCompatibilityBravoUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorTimelockControlUpgradeable
{
    uint256[50] private __gap;

    error TG_INVALID_SIGNATURES_LENGTH();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _token The Taiko token.
    /// @param _timelock The timelock contract address.
    function init(
        address _owner,
        IVotesUpgradeable _token,
        TimelockControllerUpgradeable _timelock
    )
        external
        initializer
    {
        _transferOwnership(_owner == address(0) ? msg.sender : _owner);
        __Governor_init("TaikoGovernor");
        __GovernorVotes_init(_token);
        __GovernorVotesQuorumFraction_init(4);
        __GovernorTimelockControl_init(_timelock);
    }

    /// @dev See {IGovernor-propose}
    function propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    )
        public
        override(IGovernorUpgradeable, GovernorUpgradeable, GovernorCompatibilityBravoUpgradeable)
        returns (uint256)
    {
        return super.propose(_targets, _values, _calldatas, _description);
    }

    /// @dev See {GovernorUpgradeable-supportsInterface}
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(_interfaceId);
    }

    /// @dev See {GovernorUpgradeable-state}
    function state(uint256 _proposalId)
        public
        view
        override(IGovernorUpgradeable, GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(_proposalId);
    }

    /// @notice How long after a proposal is created should voting power be fixed. A
    /// large voting delay gives users time to unstake tokens if necessary.
    /// @return The duration of the voting delay.
    function votingDelay() public pure override returns (uint256) {
        return 7200; // 1 day
    }

    /// @notice How long does a proposal remain open to votes.
    /// @return The duration of the voting period.
    function votingPeriod() public pure override returns (uint256) {
        return 50_400; // 1 week
    }

    /// @notice The number of votes required in order for a voter to become a proposer.
    /// @return The number of votes required.
    function proposalThreshold() public pure override returns (uint256) {
        return 1_000_000_000 ether / 10_000; // 0.01% of Taiko Token
    }

    /// @dev Cancel a proposal with GovernorBravo logic.
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        public
        virtual
        override(IGovernorUpgradeable, GovernorUpgradeable, GovernorCompatibilityBravoUpgradeable)
        returns (uint256)
    {
        return GovernorCompatibilityBravoUpgradeable.cancel(
            targets, values, calldatas, descriptionHash
        );
    }

    function _execute(
        uint256 _proposalId,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    )
        internal
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
    {
        super._execute(_proposalId, _targets, _values, _calldatas, _descriptionHash);
    }

    function _cancel(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    )
        internal
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (uint256)
    {
        return super._cancel(_targets, _values, _calldatas, _descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }
}
