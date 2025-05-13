// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "src/shared/common/EssentialContract.sol";

/// @title HeklaTaikoToken
/// @notice Taiko token for Taiko Hekla testnet.
/// @dev Labeled in address resolver as "taiko_token".
/// @dev Due to historical reasons, the Taiko Token on Hekla has a different storage layout compared
/// to the mainnet token contract. Therefore, we need to maintain this file.
/// @custom:security-contact security@taiko.xyz
contract HeklaTaikoToken is EssentialContract, ERC20SnapshotUpgradeable, ERC20VotesUpgradeable {
    uint256[50] private __gap;

    error TKO_INVALID_ADDR();
    error TT_INVALID_PARAM();

    constructor() EssentialContract() { }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    /// @param _recipient The address to receive initial token minting.
    function init(
        address _owner,
        string calldata _name,
        string calldata _symbol,
        address _recipient
    )
        public
        initializer
    {
        __Essential_init(_owner);
        __ERC20_init(_name, _symbol);
        __ERC20Snapshot_init();
        __ERC20Votes_init();
        __ERC20Permit_init(_name);

        // Mint 1 billion tokens
        _mint(_recipient, 1_000_000_000 ether);
    }

    /// @notice Burns tokens from the specified address.
    /// @param _from The address to burn tokens from.
    /// @param _amount The amount of tokens to burn.
    function burn(address _from, uint256 _amount) public onlyOwner {
        return _burn(_from, _amount);
    }

    /// @notice Transfers tokens to a specified address.
    /// @param _to The address to transfer tokens to.
    /// @param _amount The amount of tokens to transfer.
    /// @return A boolean indicating whether the transfer was successful or not.
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        if (_to == address(this)) revert TKO_INVALID_ADDR();
        return super.transfer(_to, _amount);
    }

    /// @notice Transfers tokens from one address to another.
    /// @param _from The address to transfer tokens from.
    /// @param _to The address to transfer tokens to.
    /// @param _amount The amount of tokens to transfer.
    /// @return A boolean indicating whether the transfer was successful or not.
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    )
        public
        override
        returns (bool)
    {
        if (_to == address(this)) revert TKO_INVALID_ADDR();
        return super.transferFrom(_from, _to, _amount);
    }

    function clock() public view override returns (uint48) {
        return SafeCastUpgradeable.toUint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        // See https://eips.ethereum.org/EIPS/eip-6372
        return "mode=timestamp";
    }

    function name() public pure override returns (string memory) {
        return "Taiko Token";
    }

    function symbol() public pure override returns (string memory) {
        return "TAIKO";
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    )
        internal
        override(ERC20Upgradeable, ERC20SnapshotUpgradeable)
    {
        return super._beforeTokenTransfer(_from, _to, _amount);
    }

    function _afterTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        return super._afterTokenTransfer(_from, _to, _amount);
    }

    function _mint(
        address _to,
        uint256 _amount
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        return super._mint(_to, _amount);
    }

    function _burn(
        address _from,
        uint256 _amount
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        return super._burn(_from, _amount);
    }

    /// @notice Batch transfers tokens
    /// @param recipients The list of addresses to transfer tokens to.
    /// @param amounts The list of amounts for transfer.
    /// @return true if the transfer is successful.
    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    )
        external
        returns (bool)
    {
        if (recipients.length != amounts.length) revert TT_INVALID_PARAM();
        uint256 size = recipients.length;
        for (uint256 i; i < size; ++i) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
        return true;
    }
}
