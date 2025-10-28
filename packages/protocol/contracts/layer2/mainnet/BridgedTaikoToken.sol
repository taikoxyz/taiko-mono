// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/governance/TaikoTokenBase.sol";
import "src/shared/vault/IBridgedERC20.sol";

/// @title BridgedTaikoToken
/// @notice The TaikoToken on L2 to support checkpoints and voting. For testnets, we do not need to
/// use this contract.
/// @custom:security-contact security@taiko.xyz
contract BridgedTaikoToken is TaikoTokenBase, IBridgedERC20 {
    address public immutable erc20Vault;

    constructor(address _erc20Vault) {
        erc20Vault = _erc20Vault;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
        __ERC20_init("Taiko Token", "TAIKO");
        __ERC20Votes_init();
        __ERC20Permit_init("Taiko Token");
    }

    function mint(
        address _account,
        uint256 _amount
    )
        external
        override
        whenNotPaused
        onlyFromOwnerOr(erc20Vault)
        nonReentrant
    {
        _mint(_account, _amount);
    }

    function burn(uint256 _amount)
        external
        override
        whenNotPaused
        onlyFromOwnerOr(erc20Vault)
        nonReentrant
    {
        _burn(msg.sender, _amount);
    }

    /// @notice Gets the canonical token's address and chain ID.
    /// @return The canonical token's address.
    /// @return The canonical token's chain ID.
    function canonical() public pure returns (address, uint256) {
        // 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 is the TAIKO token on Ethereum mainnet
        return (0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800, 1);
    }

    function changeMigrationStatus(address, bool) public pure notImplemented { }
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
