// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../tokenvault/IBridgedERC20.sol";
/// @notice TaikoToken was `EssentialContract, ERC20SnapshotUpgradeable, ERC20VotesUpgradeable`.
/// We use this contract to take 50 more slots to remove `ERC20SnapshotUpgradeable` from the parent
/// contract list.
/// We can simplify the code since we no longer need to maintain upgradability with Hekla.
// solhint-disable contract-name-camelcase

abstract contract EssentialContract_ is EssentialContract {
    // solhint-disable var-name-mixedcase
    uint256[50] private __slots_previously_used_by_ERC20SnapshotUpgradeable;
}

/// @title TaikoToken
/// @notice The TaikoToken (TKO), in the protocol is used for prover collateral
/// in the form of bonds. It is an ERC20 token with 18 decimal places of
/// precision.
/// @dev Labeled in AddressResolver as "taiko_token"
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoTokenBase is EssentialContract_, ERC20VotesUpgradeable {
    uint256[50] private __gap;

    error TKO_INVALID_ADDR();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    function __TaikoToken_init(
        address _owner,
        address _addressManager,
        string memory _name,
        string memory _symbol
    )
        internal
        onlyInitializing
    {
        if (_addressManager == address(0)) {
            __Essential_init(_owner);
        } else {
            __Essential_init(_owner, _addressManager);
        }
        __Context_init_unchained();
        __ERC20_init(_name, _symbol);
        __ERC20Votes_init();
        __ERC20Permit_init(_name);
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
}

contract TaikoToken is TaikoTokenBase {
    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _recipient The address to receive initial token minting.
    function init(address _owner, string calldata _symbol, address _recipient) public initializer {
        __TaikoToken_init(_owner, address(0), "Taiko Token", "TKO");
        // Mint 1 billion tokens
        _mint(_recipient, 1_000_000_000 ether);
    }
}

contract BridgedTaikoToken is TaikoTokenBase, IBridgedERC20, IERC165 {
    bytes4 internal constant IERC165_INTERFACE_ID = bytes4(keccak256("supportsInterface(bytes4)"));

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner, address _addressManager) external initializer {
        require(_addressManager != address(0), "");
        __TaikoToken_init(_owner, _addressManager, "Taiko Token", "TKO");
    }

    function mint(
        address _account,
        uint256 _amount
    )
        external
        override
        onlyFromNamed(LibStrings.B_ERC20_VAULT)
    {
        _mint(_account, _amount);
    }

    function burn(uint256 _amount) external override onlyFromNamed(LibStrings.B_ERC20_VAULT) {
        _burn(msg.sender, _amount);
    }

    function owner() public view override(IBridgedERC20, OwnableUpgradeable) returns (address) {
        return super.owner();
    }

    /// @notice Gets the canonical token's address and chain ID.
    /// @return The canonical token's address.
    /// @return The canonical token's chain ID.
    function canonical() public pure returns (address, uint256) {
        // 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 is the TKO's mainnet address
        // 1 is the Ethereum's network id.
        return (0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800, 1);
    }

    /// @notice Checks if the contract supports the given interface.
    /// @param _interfaceId The interface identifier.
    /// @return true if the contract supports the interface, false otherwise.
    function supportsInterface(bytes4 _interfaceId) public pure override returns (bool) {
        return
            _interfaceId == type(IBridgedERC20).interfaceId || _interfaceId == IERC165_INTERFACE_ID;
    }

    function changeMigrationStatus(address, bool) public pure {
        revert("not supported");
    }
}
