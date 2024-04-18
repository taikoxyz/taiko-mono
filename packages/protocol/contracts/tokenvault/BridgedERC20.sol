// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "./LibBridgedToken.sol";
import "./BridgedERC20Base.sol";

/// @title BridgedERC20
/// @notice An upgradeable ERC20 contract that represents tokens bridged from
/// another chain.
/// @custom:security-contact security@taiko.xyz
contract BridgedERC20 is
    BridgedERC20Base,
    IERC20MetadataUpgradeable,
    ERC20SnapshotUpgradeable,
    ERC20VotesUpgradeable
{
    /// @dev Slot 1.
    address public srcToken;

    uint8 private __srcDecimals;

    /// @dev Slot 2.
    uint256 public srcChainId;

    /// @dev Slot 3.
    address public snapshooter;

    uint256[47] private __gap;

    error BTOKEN_CANNOT_RECEIVE();
    error BTOKEN_UNAUTHORIZED();

    modifier onlyAuthorizedForSnapshot() {
        if (!isAuthorizedForSnapshot(msg.sender)) revert BTOKEN_UNAUTHORIZED();
        _;
    }

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
        __ERC20Snapshot_init();
        __ERC20Votes_init();
        __ERC20Permit_init(_name);

        // Set contract properties
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        __srcDecimals = _decimals;
    }

    /// @notice Set the snapshoter address.
    /// @param _snapshooter snapshooter address.
    function setSnapshooter(address _snapshooter) external onlyOwner {
        snapshooter = _snapshooter;
    }

    /// @notice Creates a new token snapshot.
    function snapshot() external onlyAuthorizedForSnapshot returns (uint256) {
        return _snapshot();
    }

    /// @notice Gets the name of the token.
    /// @return The name.
    function name()
        public
        view
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (string memory)
    {
        return LibBridgedToken.buildName(super.name(), srcChainId);
    }

    /// @notice Gets the symbol of the bridged token.
    /// @return The symbol.
    function symbol()
        public
        view
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (string memory)
    {
        return LibBridgedToken.buildSymbol(super.symbol());
    }

    /// @notice Gets the number of decimal places of the token.
    /// @return The number of decimal places of the token.
    function decimals()
        public
        view
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (uint8)
    {
        return __srcDecimals;
    }

    /// @notice Gets the current snapshot ID.
    /// @return The current snapshot ID.
    function currentSnapshotId() public view returns (uint256) {
        return _getCurrentSnapshotId();
    }

    /// @notice Checks if an address can take a snapshot.
    /// @param addr The address.
    /// @return true if the address can perform a snapshot, false otherwise.
    function isAuthorizedForSnapshot(address addr) public view returns (bool) {
        if (addr == address(0)) return false;
        if (addr == snapshooter) return true;
        if (
            addr == resolve(LibStrings.B_TAIKO, true)
                && address(this) == resolve(LibStrings.B_TAIKO_TOKEN, true)
        ) return true;
        return false;
    }

    /// @notice Gets the canonical token's address and chain ID.
    /// @return The canonical token's address.
    /// @return The canonical token's chain ID.
    function canonical() external view returns (address, uint256) {
        return (srcToken, srcChainId);
    }

    function _mintToken(address _account, uint256 _amount) internal override {
        return _mint(_account, _amount);
    }

    function _burnToken(address _from, uint256 _amount) internal override {
        return _burn(_from, _amount);
    }

    /// @dev For ERC20SnapshotUpgradeable and ERC20VotesUpgradeable, need to implement the following
    /// functions
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    )
        internal
        override(ERC20Upgradeable, ERC20SnapshotUpgradeable)
    {
        if (_to == address(this)) revert BTOKEN_CANNOT_RECEIVE();
        if (paused()) revert INVALID_PAUSE_STATUS();
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
}
