// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IOptaiko
/// @notice Interface for the Optaiko Core contract
interface IOptaiko {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Represents a single leg of an option position
    /// @dev Each leg defines a specific liquidity range and type (long/short)
    struct Leg {
        bool isLong; // true = Long (Buyer), false = Short (Seller)
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity; // Amount of liquidity for this leg
    }

    /// @notice Represents a complete option position with one or more legs
    /// @dev Positions can have multiple legs to create complex strategies
    struct OptionPosition {
        address owner;
        bytes32 poolId; // Uniswap V4 PoolId
        Leg[] legs;
        uint256 openedAt;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new option position is minted
    event OptionMinted(uint256 indexed positionId, address indexed owner, bytes32 poolId);

    /// @notice Emitted when an option position is burned (closed)
    event OptionBurned(uint256 indexed positionId, address indexed owner, uint256 settledPremium);

    // ---------------------------------------------------------------
    // Functions
    // ---------------------------------------------------------------

    /// @notice Mints a new option position
    /// @param poolId The Uniswap V4 Pool ID
    /// @param legs The list of legs for this option strategy
    /// @return positionId The ID of the newly created position
    function mintOption(bytes32 poolId, Leg[] calldata legs) external returns (uint256 positionId);

    /// @notice Burns (closes) an existing option position
    /// @param positionId The ID of the position to close
    function burnOption(uint256 positionId) external;

    /// @notice Returns the details of a position
    /// @param positionId The ID of the position
    /// @return position The position details
    function getPosition(uint256 positionId) external view returns (OptionPosition memory);
}
