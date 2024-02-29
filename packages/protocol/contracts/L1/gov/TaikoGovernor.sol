// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import
    "@openzeppelin/contracts-upgradeable/governance/compatibility/GovernorCompatibilityBravoUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "../../common/EssentialContract.sol";

/// @title TaikoGovernor
/// @custom:security-contact security@taiko.xyz
contract TaikoGovernor is
    EssentialContract,
    GovernorCompatibilityBravoUpgradeable,
    GovernorVotesUpgradeable,
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
        __Essential_init(_owner);
        __Governor_init("TaikoGovernor");
        __GovernorCompatibilityBravo_init();
        __GovernorVotes_init(_token);
        __GovernorVotesQuorumFraction_init(4);
        __GovernorTimelockControl_init(_timelock);
    }

    /// @dev See {IGovernor-propose}
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        public
        override(IGovernorUpgradeable, GovernorUpgradeable, GovernorCompatibilityBravoUpgradeable)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }

    /// @notice An overwrite of GovernorCompatibilityBravoUpgradeable's propose() as that one does
    /// not check that the length of signatures equal the calldata.
    /// @dev See vulnerability description here:
    /// https://github.com/taikoxyz/taiko-mono/security/dependabot/114
    /// See fix in OZ 4.8.3 here:
    /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/0a25c1940ca220686588c4af3ec526f725fe2582/contracts/governance/compatibility/GovernorCompatibilityBravo.sol#L72
    /// See {GovernorCompatibilityBravoUpgradeable-propose}
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    )
        public
        virtual
        override(GovernorCompatibilityBravoUpgradeable)
        returns (uint256)
    {
        if (signatures.length != calldatas.length) revert TG_INVALID_SIGNATURES_LENGTH();

        return GovernorCompatibilityBravoUpgradeable.propose(
            targets, values, signatures, calldatas, description
        );
    }

    /// @dev See {GovernorUpgradeable-supportsInterface}
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @dev See {GovernorUpgradeable-state}
    function state(uint256 proposalId)
        public
        view
        override(IGovernorUpgradeable, GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
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

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
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
