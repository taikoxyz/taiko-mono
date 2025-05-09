// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/token/TaikoTokenBase.sol";

/// @title TaikoToken
/// @notice The TaikoToken (TKO), in the protocol is used for prover collateral
/// in the form of bonds. It is an ERC20 token with 18 decimal places of precision.
/// @dev Labeled in address resolver as "taiko_token"
/// @dev On Ethereum, this contract is deployed behind a proxy at
/// 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 (token.taiko.eth)
/// @custom:security-contact security@taiko.xyz
contract TaikoToken is TaikoTokenBase {
    address public constant TAIKO_FOUNDATION_TREASURY = 0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da;
    // TODO(bernet): what's the address?
    address public constant TAIKO_DAO_CONTROLLER = 0x0000000000000000000000000000000000000000;

    error TT_INVALID_PARAM();
    error TT_NON_VOTING_ACCOUNT();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _recipient The address to receive initial token minting.
    function init(address _owner, address _recipient) public initializer {
        __Essential_init(_owner);
        __ERC20_init("Taiko Token", "TAIKO");
        __ERC20Votes_init();
        __ERC20Permit_init("Taiko Token");
        // Mint 1 billion tokens
        _mint(_recipient, 1_000_000_000 ether);
    }

    function delegate(address account) public override {
        address[] memory nonVotingAccounts = getNonVotingAccounts();
        // Special checks to avoid reading from storage slots
        for (uint256 i; i < nonVotingAccounts.length; ++i) {
            require(msg.sender != nonVotingAccounts[i], TT_NON_VOTING_ACCOUNT());
        }
        super.delegate(account);
    }

    function getPastVotes(
        address account,
        uint256 timepoint
    )
        public
        view
        override
        returns (uint256)
    {
        address[] memory nonVotingAccounts = getNonVotingAccounts();
        for (uint256 i; i < nonVotingAccounts.length; ++i) {
            if (account == nonVotingAccounts[i]) {
                return 0;
            }
        }
        return super.getPastVotes(account, timepoint);
    }

    /// @notice This override modifies the return value to reflect the past total supply eligible
    /// for voting.
    function getPastTotalSupply(uint256 timepoint) public view override returns (uint256) {
        address[] memory nonVotingAccounts = getNonVotingAccounts();
        uint256 nonVotingSupply;
        for (uint256 i; i < nonVotingAccounts.length; ++i) {
            nonVotingSupply += balanceOf(nonVotingAccounts[i]);
        }
        nonVotingSupply += balanceOf(address(0));
        return super.getPastTotalSupply(timepoint) - nonVotingSupply;
    }

    /// @notice Returns the list of accounts that are not eligible for voting.
    /// @return accounts_ The list of accounts that are not eligible for voting.
    function getNonVotingAccounts() public pure virtual returns (address[] memory accounts_) {
        accounts_ = new address[](2);
        accounts_[0] = TAIKO_FOUNDATION_TREASURY;
        accounts_[1] = TAIKO_DAO_CONTROLLER;
    }
}
