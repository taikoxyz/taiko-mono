// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/governance/TaikoTokenBase.sol";

import "./TaikoToken_Layout.sol"; // DO NOT DELETE

/// @title TaikoToken
/// @notice The TaikoToken (TKO), in the protocol is used for prover collateral
/// in the form of bonds. It is an ERC20 token with 18 decimal places of precision.
/// @dev Labeled in address resolver as "taiko_token"
/// @dev On Ethereum, this contract is deployed behind a proxy at
/// 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 (token.taiko.eth)
/// @custom:security-contact security@taiko.xyz
contract TaikoToken is TaikoTokenBase {
    // treasury.taiko.eth
    address public constant TAIKO_FOUNDATION_TREASURY = 0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da;
    // daocontroller.taiko.eth
    address public constant TAIKO_DAO_CONTROLLER = 0xfC3C4ca95a8C4e5a587373f1718CD91301d6b2D3;
    // v20.based.taiko.eth
    address public constant TAIKO_ERC20_VAULT = 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab;

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

    function init2() external reinitializer(2) {
        // Ensure non-voting accounts are forced to delegate to themselves so their getPastVotes
        // will return their balance as their voting power.
        address[] memory accounts = getNonVotingAccounts();
        for (uint256 i; i < accounts.length; ++i) {
            _delegate(accounts[i], accounts[i]);
        }
    }

    function delegate(address _account) public override {
        // Ensure non-voting accounts cannot delegate or being delegated to.
        address[] memory accounts = getNonVotingAccounts();
        for (uint256 i; i < accounts.length; ++i) {
            require(_account != accounts[i] && msg.sender != accounts[i], TT_NON_VOTING_ACCOUNT());
        }
        super.delegate(_account);
    }

    function getPastVotes(
        address _account,
        uint256 _timepoint
    )
        public
        view
        override
        returns (uint256)
    {
        address[] memory accounts = getNonVotingAccounts();
        for (uint256 i; i < accounts.length; ++i) {
            if (_account == accounts[i]) return 0;
        }
        return super.getPastVotes(_account, _timepoint);
    }

    /// @notice This override modifies the return value to reflect the past total supply eligible
    /// for voting.
    function getPastTotalSupply(uint256 _timepoint) public view override returns (uint256) {
        uint256 nonVotingSupply;
        address[] memory accounts = getNonVotingAccounts();
        for (uint256 i; i < accounts.length; ++i) {
            // Must use `super.getPastVotes` instead of `this.getPastVotes`
            nonVotingSupply += super.getPastVotes(accounts[i], _timepoint);
        }
        return super.getPastTotalSupply(_timepoint) - nonVotingSupply;
    }

    /// @notice Returns the list of accounts that are not eligible for voting.
    /// @return accounts_ The list of accounts that are not eligible for voting.
    function getNonVotingAccounts() public pure virtual returns (address[] memory accounts_) {
        accounts_ = new address[](4);
        accounts_[0] = address(0);
        accounts_[1] = TAIKO_FOUNDATION_TREASURY;
        accounts_[2] = TAIKO_DAO_CONTROLLER;
        accounts_[3] = TAIKO_ERC20_VAULT;
    }
}
