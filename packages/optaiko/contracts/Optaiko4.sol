// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IOptaiko4 } from "./IOptaiko4.sol";
import "./Optaiko4_Layout.sol";
import {
    Ownable2StepUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IPoolManager } from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import { PoolIdLibrary } from "@uniswap/v4-core/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/types/PoolKey.sol";

/// @title Optaiko4
/// @author Optaiko Team
/// @notice Core contract for the Optaiko options protocol built on top of Uniswap V4
/// @dev This contract implements a Panoptic-style options protocol where options are represented
/// as positions in Uniswap V4 liquidity pools. The protocol allows users to:
/// - Mint options (both long and short) by creating positions with specific tick ranges
/// - Burn (close) positions to realize profits or losses
/// - Collect streaming premia based on fees accrued from the underlying Uniswap V4 pool
///
/// **Core Concepts:**
/// 1. **Short Options**: When a user mints a short option, they deposit liquidity into a Uniswap V4 pool
///    at a specific tick range. This liquidity earns fees, which represent the "streaming premium"
///    that option sellers receive.
/// 2. **Long Options**: When a user mints a long option, they conceptually "borrow" liquidity from the pool
///    (tracked via internal accounting). Long option holders pay streaming premia to short option holders.
/// 3. **Multi-Leg Positions**: Users can create complex option strategies (e.g., spreads, straddles)
///    by combining multiple legs in a single position.
/// 4. **Streaming Premia**: Unlike traditional options with one-time premiums, this protocol uses
///    a streaming model where premia accrue continuously based on liquidity utilization and fees.
///
/// **Upgradeability:**
/// This contract uses the UUPS (Universal Upgradeable Proxy Standard) pattern for upgradeability.
/// Only the contract owner can authorize upgrades.
///
/// @custom:security-contact security@optaiko.xyz
contract Optaiko4 is
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    IOptaiko4
{
    using PoolIdLibrary for PoolKey;

    // ---------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------

    /// @notice The Uniswap V4 Pool Manager contract
    /// @dev This is the core Uniswap V4 contract that manages all pools
    IPoolManager public poolManager;

    /// @notice Counter for generating unique position IDs
    /// @dev Packed with poolManager in the same storage slot (address 160 bits + uint64 64 bits = 224 bits)
    uint64 private _positionIdCounter;

    /// @notice Mapping from position ID to position data
    /// @dev Position IDs are auto-incremented starting from 1
    mapping(uint256 => IOptaiko4.OptionPosition) private _positions;

    /// @notice Mapping to track accrued premia for each position
    /// @dev Premia is tracked in the base currency of the pool
    mapping(uint256 => uint256) public accruedPremia;

    /// @notice Mapping to track the last update timestamp for each position
    mapping(uint256 => uint256) public lastUpdateTimestamp;

    uint256[46] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when the Pool Manager is updated
    event PoolManagerUpdated(address indexed oldManager, address indexed newManager);

    // ---------------------------------------------------------------
    // Initialization
    // ---------------------------------------------------------------

    /// @notice Initializes the contract
    /// @dev This function replaces the constructor for upgradeable contracts
    /// @param _poolManager The address of the Uniswap V4 Pool Manager
    /// @param _owner The address of the contract owner
    function initialize(address _poolManager, address _owner) external initializer {
        require(_poolManager != address(0), InvalidPoolManager());

        __UUPSUpgradeable_init();
        __Ownable_init(_owner);
        __ReentrancyGuard_init();

        poolManager = IPoolManager(_poolManager);
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Mints a new option position
    /// @dev This function creates a new multi-leg option position. Each leg can be either:
    /// - A short leg (isLong = false): Deposits liquidity to the Uniswap V4 pool
    /// - A long leg (isLong = true): Conceptually borrows liquidity (tracked internally)
    ///
    /// **Important Notes:**
    /// - The caller must approve this contract to spend the required tokens before calling this function
    /// - All legs in a position share the same poolId
    /// - Tick ranges must align with the pool's tick spacing
    /// - For short legs, this contract will interact with the Uniswap V4 PoolManager to add liquidity
    ///
    /// @param poolId The Uniswap V4 Pool ID (derived from PoolKey)
    /// @param legs Array of legs defining the option strategy
    /// @return positionId The ID of the newly created position
    function mintOption(
        bytes32 poolId,
        IOptaiko4.Leg[] calldata legs
    )
        external
        override
        nonReentrant
        returns (uint256 positionId)
    {
        // Validate inputs
        require(legs.length > 0, ZeroLiquidity());

        // Generate new position ID
        positionId = ++_positionIdCounter;

        // Create the position storage
        IOptaiko4.OptionPosition storage position = _positions[positionId];
        position.owner = msg.sender;
        position.poolId = poolId;
        position.openedAt = block.timestamp;

        // Process each leg
        // Note: In a full implementation, we would:
        // 1. For short legs: Call poolManager.modifyLiquidity() to add liquidity
        // 2. For long legs: Update internal accounting to track "borrowed" liquidity
        // 3. Calculate collateral requirements
        // 4. Transfer tokens from the user
        //
        // For this clean-room implementation, we focus on the structure and documentation.
        for (uint256 i; i < legs.length; ++i) {
            // Validate each leg (assuming tick spacing of 60 for example)
            // In production, we'd fetch the actual tick spacing from the pool
            _validateLeg(legs[i], 60);

            // Store the leg
            position.legs.push(legs[i]);
        }

        // Initialize premium tracking
        lastUpdateTimestamp[positionId] = block.timestamp;

        emit OptionMinted(positionId, msg.sender, poolId);
    }

    /// @notice Burns (closes) an existing option position
    /// @dev This function closes a position and settles all outstanding premia. The process involves:
    /// 1. Verifying the caller owns the position
    /// 2. Calculating and settling any accrued premia
    /// 3. For short legs: Removing liquidity from the Uniswap V4 pool
    /// 4. For long legs: Settling the internal accounting
    /// 5. Transferring tokens back to the user
    ///
    /// **Important Notes:**
    /// - Only the position owner can burn their position
    /// - Premium settlement occurs automatically during the burn
    /// - The position is deleted from storage after burning to save gas
    ///
    /// @param positionId The ID of the position to close
    function burnOption(uint256 positionId) external override nonReentrant {
        IOptaiko4.OptionPosition storage position = _positions[positionId];

        // Verify ownership
        require(position.owner == msg.sender, Unauthorized());
        require(position.owner != address(0), PositionDoesNotExist());

        // Calculate and settle premia
        uint256 settledPremium = _settlePremia(positionId);

        // Process each leg
        // Note: In a full implementation, we would:
        // 1. For short legs: Call poolManager.modifyLiquidity() to remove liquidity
        // 2. For long legs: Update internal accounting
        // 3. Transfer tokens back to the user
        //
        // For this clean-room implementation, we focus on the structure and documentation.

        // Clean up storage
        delete _positions[positionId];
        delete accruedPremia[positionId];
        delete lastUpdateTimestamp[positionId];

        emit OptionBurned(positionId, msg.sender, settledPremium);
    }

    /// @notice Returns the details of a position
    /// @dev Returns all information about a position including owner, pool, legs, and timestamps
    /// @param positionId The ID of the position to query
    /// @return position The complete position data
    function getPosition(uint256 positionId)
        external
        view
        override
        returns (IOptaiko4.OptionPosition memory position)
    {
        position = _positions[positionId];
        require(position.owner != address(0), PositionDoesNotExist());
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Settles accrued premia for a position
    /// @dev This internal function calculates and settles streaming premia. The calculation is based on:
    /// - Time elapsed since last update
    /// - Fees collected from the underlying Uniswap V4 pool (for short positions)
    /// - Liquidity utilization (for long positions)
    ///
    /// In a full implementation, this would:
    /// 1. Query the Uniswap V4 PoolManager for accrued fees
    /// 2. Calculate the delta since the last settlement
    /// 3. Update internal accounting for long/short premia flows
    /// 4. Transfer any net premia to/from the user
    ///
    /// @param positionId The ID of the position to settle
    /// @return settledAmount The amount of premia settled
    function _settlePremia(uint256 positionId) internal returns (uint256 settledAmount) {
        // In a full implementation, we would calculate premia based on:
        // - Fees accrued in the Uniswap V4 pool
        // - Liquidity utilization
        // - Time elapsed
        //
        // For this clean-room implementation, we just return the stored value
        settledAmount = accruedPremia[positionId];

        // Update timestamp
        lastUpdateTimestamp[positionId] = block.timestamp;

        return settledAmount;
    }

    /// @notice Validates a leg's parameters
    /// @dev Internal helper to validate tick ranges and liquidity
    /// @param leg The leg to validate
    /// @param tickSpacing The tick spacing of the pool
    function _validateLeg(IOptaiko4.Leg memory leg, int24 tickSpacing) internal pure {
        require(leg.tickLower < leg.tickUpper, InvalidTickRange());
        require(leg.tickLower % tickSpacing == 0, InvalidTickRange());
        require(leg.tickUpper % tickSpacing == 0, InvalidTickRange());
        require(leg.liquidity != 0, ZeroLiquidity());
    }

    /// @notice Authorizes an upgrade to a new implementation
    /// @dev This function is required by the UUPS pattern. Only the owner can authorize upgrades.
    /// @param newImplementation The address of the new implementation contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // Additional upgrade validation logic can be added here
        // For example: checking that the new implementation is a valid contract,
        // verifying upgrade permissions, implementing timelock mechanisms, etc.
    }

    // ---------------------------------------------------------------
    // Admin Functions
    // ---------------------------------------------------------------

    /// @notice Updates the Pool Manager address
    /// @dev Only callable by the contract owner. Use with extreme caution as this changes
    /// the core dependency of the protocol.
    /// @param _newPoolManager The address of the new Pool Manager
    function updatePoolManager(address _newPoolManager) external onlyOwner {
        require(_newPoolManager != address(0), InvalidPoolManager());

        address oldManager = address(poolManager);
        poolManager = IPoolManager(_newPoolManager);

        emit PoolManagerUpdated(oldManager, _newPoolManager);
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InsufficientPremium();
    error InvalidPoolManager();
    error InvalidTickRange();
    error OptionAlreadyClosed();
    error PositionDoesNotExist();
    error Unauthorized();
    error ZeroLiquidity();
}
