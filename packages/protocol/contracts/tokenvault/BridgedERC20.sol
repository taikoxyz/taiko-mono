// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "./LibBridgedToken.sol";
import "./BridgedERC20Base.sol";

/// @notice BridgedERC20 was `BridgedERC20Base, ERC20SnapshotUpgradeable, ERC20VotesUpgradeable`.
/// We use this contract to take 50 more slots to remove `ERC20SnapshotUpgradeable` from the parent
/// contract list.
/// We can simplify the code since we no longer need to maintain upgradability with Hekla.
// solhint-disable contract-name-camelcase
abstract contract BridgedERC20Base_ is BridgedERC20Base {
    // solhint-disable var-name-mixedcase
    uint256[50] private __slots_previously_used_by_ERC20SnapshotUpgradeable;
}

/// @title BridgedERC20
/// @notice An upgradeable ERC20 contract that represents tokens bridged from
/// another chain.
/// @custom:security-contact security@taiko.xyz
contract BridgedERC20 is BridgedERC20Base_, ERC20VotesUpgradeable {
    /// @dev Slot 1.
    address public srcToken;

    uint8 private __srcDecimals;

    /// @dev Slot 2.
    uint256 public srcChainId;

    /// @dev Slot 3.
    address private __deprecated1;

    uint256[47] private __gap;

    error BTOKEN_CANNOT_RECEIVE();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _srcToken The source token address.
    /// @param _srcChainId The source chain ID.
    /// @param _decimals The number of decimal places of the source token.
    /// @param _symbol The symbol of the token.
    /// @param _name The name of the token.
    function init(
        address _owner,
        address _addressManager,
        address _srcToken,
        uint256 _srcChainId,
        uint8 _decimals,
        string calldata _symbol,
        string calldata _name
    )
        external
        initializer
    {
        // Check if provided parameters are valid
        LibBridgedToken.validateInputs(_srcToken, _srcChainId, _symbol, _name);
        __Essential_init(_owner, _addressManager);
        __ERC20_init(_name, _symbol);
        __ERC20Votes_init();
        __ERC20Permit_init(_name);

        // Set contract properties
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        __srcDecimals = _decimals;
    }

    /// @notice Gets the name of the token.
    /// @return The name.
    function name() public view override returns (string memory) {
        return LibBridgedToken.buildName(super.name(), srcChainId);
    }

    /// @notice Gets the symbol of the bridged token.
    /// @return The symbol.
    function symbol() public view override returns (string memory) {
        return LibBridgedToken.buildSymbol(super.symbol());
    }

    /// @notice Gets the number of decimal places of the token.
    /// @return The number of decimal places of the token.
    function decimals() public view override returns (uint8) {
        return __srcDecimals;
    }

    /// @notice Gets the canonical token's address and chain ID.
    /// @return The canonical token's address.
    /// @return The canonical token's chain ID.
    function canonical() external view returns (address, uint256) {
        return (srcToken, srcChainId);
    }

    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal override {
        if (_to == address(this)) revert BTOKEN_CANNOT_RECEIVE();
        if (paused()) revert INVALID_PAUSE_STATUS();
        return super._beforeTokenTransfer(_from, _to, _amount);
    }

    function _mint(
        address _to,
        uint256 _amount
    )
        internal
        override(BridgedERC20Base, ERC20VotesUpgradeable)
    {
        return super._mint(_to, _amount);
    }

    function _burn(
        address _from,
        uint256 _amount
    )
        internal
        override(BridgedERC20Base, ERC20VotesUpgradeable)
    {
        return super._burn(_from, _amount);
    }
}
