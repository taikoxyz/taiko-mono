// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICircleFiatToken
/// @notice Minimal interface required for Taiko's Hoodi USDC deployment and bridge flow.
/// @custom:security-contact security@taiko.xyz
interface ICircleFiatToken {
    /// @notice Initializes the fiat token proxy with its v1 state.
    function initialize(
        string calldata _tokenName,
        string calldata _tokenSymbol,
        string calldata _tokenCurrency,
        uint8 _tokenDecimals,
        address _newMasterMinter,
        address _newPauser,
        address _newBlacklister,
        address _newOwner
    )
        external;

    /// @notice Initializes the v2 state.
    function initializeV2(string calldata _newName) external;

    /// @notice Initializes the v2.1 state.
    function initializeV2_1(address _lostAndFound) external;

    /// @notice Initializes the v2.2 state.
    function initializeV2_2(
        address[] calldata _accountsToBlacklist,
        string calldata _newSymbol
    )
        external;

    /// @notice Configures a minter allowance.
    function configureMinter(
        address _minter,
        uint256 _minterAllowedAmount
    )
        external
        returns (bool);

    /// @notice Returns whether an account is a minter.
    function isMinter(address _account) external view returns (bool);

    /// @notice Returns the remaining mint allowance for a minter.
    function minterAllowance(address _minter) external view returns (uint256);

    /// @notice Mints tokens to an account.
    function mint(address _to, uint256 _amount) external returns (bool);

    /// @notice Burns tokens from msg.sender.
    function burn(uint256 _amount) external;

    /// @notice Approves an allowance.
    function approve(address _spender, uint256 _amount) external returns (bool);

    /// @notice Transfers from an approved owner.
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    )
        external
        returns (bool);

    /// @notice Returns the owner.
    function owner() external view returns (address);

    /// @notice Returns the master minter.
    function masterMinter() external view returns (address);

    /// @notice Returns the pauser.
    function pauser() external view returns (address);

    /// @notice Returns the blacklister.
    function blacklister() external view returns (address);

    /// @notice Returns token metadata.
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    /// @notice Returns token state.
    function totalSupply() external view returns (uint256);
    function balanceOf(address _account) external view returns (uint256);
}

/// @title ICircleFiatTokenProxy
/// @notice Minimal admin interface for Circle's FiatToken proxy.
/// @custom:security-contact security@taiko.xyz
interface ICircleFiatTokenProxy {
    /// @notice Changes the proxy admin.
    function changeAdmin(address _newAdmin) external;
}
