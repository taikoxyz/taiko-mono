// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/governance/TaikoTokenBase.sol";

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

// Storage Layout ---------------------------------------------------------------
//
//   _initialized                   | uint8                                              | Slot: 0    | Offset: 0    | Bytes: 1
//   _initializing                  | bool                                               | Slot: 0    | Offset: 1    | Bytes: 1
//   __gap                          | uint256[50]                                        | Slot: 1    | Offset: 0    | Bytes: 1600
//   _owner                         | address                                            | Slot: 51   | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 52   | Offset: 0    | Bytes: 1568
//   _pendingOwner                  | address                                            | Slot: 101  | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 102  | Offset: 0    | Bytes: 1568
//   __gapFromOldAddressResolver    | uint256[50]                                        | Slot: 151  | Offset: 0    | Bytes: 1600
//   __reentry                      | uint8                                              | Slot: 201  | Offset: 0    | Bytes: 1
//   __paused                       | uint8                                              | Slot: 201  | Offset: 1    | Bytes: 1
//   __gap                          | uint256[49]                                        | Slot: 202  | Offset: 0    | Bytes: 1568
//   __slots_previously_used_by_ERC20SnapshotUpgradeable | uint256[50]                                        | Slot: 251  | Offset: 0    | Bytes: 1600
//   _balances                      | mapping(address => uint256)                        | Slot: 301  | Offset: 0    | Bytes: 32
//   _allowances                    | mapping(address => mapping(address => uint256))    | Slot: 302  | Offset: 0    | Bytes: 32
//   _totalSupply                   | uint256                                            | Slot: 303  | Offset: 0    | Bytes: 32
//   _name                          | string                                             | Slot: 304  | Offset: 0    | Bytes: 32
//   _symbol                        | string                                             | Slot: 305  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[45]                                        | Slot: 306  | Offset: 0    | Bytes: 1440
//   _hashedName                    | bytes32                                            | Slot: 351  | Offset: 0    | Bytes: 32
//   _hashedVersion                 | bytes32                                            | Slot: 352  | Offset: 0    | Bytes: 32
//   _name                          | string                                             | Slot: 353  | Offset: 0    | Bytes: 32
//   _version                       | string                                             | Slot: 354  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[48]                                        | Slot: 355  | Offset: 0    | Bytes: 1536
//   _nonces                        | mapping(address => struct CountersUpgradeable.Counter) | Slot: 403  | Offset: 0    | Bytes: 32
//   _PERMIT_TYPEHASH_DEPRECATED_SLOT | bytes32                                            | Slot: 404  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[49]                                        | Slot: 405  | Offset: 0    | Bytes: 1568
//   _delegates                     | mapping(address => address)                        | Slot: 454  | Offset: 0    | Bytes: 32
//   _checkpoints                   | mapping(address => struct ERC20VotesUpgradeable.Checkpoint[]) | Slot: 455  | Offset: 0    | Bytes: 32
//   _totalSupplyCheckpoints        | struct ERC20VotesUpgradeable.Checkpoint[]          | Slot: 456  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[47]                                        | Slot: 457  | Offset: 0    | Bytes: 1504
//   __gap                          | uint256[50]                                        | Slot: 504  | Offset: 0    | Bytes: 1600
