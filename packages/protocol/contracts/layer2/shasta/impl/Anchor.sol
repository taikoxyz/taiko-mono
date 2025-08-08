// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EssentialContract } from "contracts/shared/common/EssentialContract.sol";
import { IAnchor } from "../iface/IAnchor.sol";
import { IShastaBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { ISyncedBlockManager } from "contracts/shared/shasta/iface/ISyncedBlockManager.sol";
import { LibBondOperation } from "contracts/shared/shasta/libs/LibBondOperation.sol";
import { LibMath } from "contracts/shared/libs/LibMath.sol";

/// @title Anchor
/// @notice Manages L2 state synchronization with L1 through a secure system-level interface
/// @dev Critical security component: Only updatable by a keyless system address to prevent external
/// manipulation.
///      Handles block anchoring, bond payments, and gas issuance rate adjustments.
/// @custom:security-contact security@taiko.xyz
contract Anchor is EssentialContract, IAnchor {
    using LibMath for uint256;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev Maximum gas issuance adjustment per update (0.01% = 1/10000)
    uint32 private constant _GAS_ISSUANCE_MAX_ADJUSTMENT_DIVISOR = 10_000;

    /// @dev The keyless address that can transact the saveState function.
    address private constant _ANCHOR_TRANSACTOR =
        address(bytes20(keccak256("TAIKO_ANCHOR_TRANSACTOR")));

    // ---------------------------------------------------------------
    // Immutable Configuration
    // ---------------------------------------------------------------

    /// @notice External contract dependencies
    IShastaBondManager public immutable bondManager;
    ISyncedBlockManager public immutable syncedBlockManager;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Current anchor state (4 storage slots)
    State private _state;

    /// @dev Storage gap for future upgrades
    uint256[46] private __gap;

    constructor(
        IShastaBondManager _bondManager,
        ISyncedBlockManager _syncedBlockManager
    )
        EssentialContract()
    {
        bondManager = _bondManager;
        syncedBlockManager = _syncedBlockManager;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the anchor contract with initial state
    /// @param _owner Contract owner address for admin functions
    /// @param _initialState Initial anchor state configuration
    function init(address _owner, State memory _initialState) external initializer {
        __Essential_init(_owner);
        _state = _initialState;
    }

    /// @notice Returns the current anchor state
    /// @return Current state including block info, gas issuance, and bond operations
    function getState() external view returns (State memory) {
        return _state;
    }

    /// @notice Atomically updates the anchor state with L1 synchronization data
    /// @param _newState New state containing L1 block info and configuration
    /// @param _bondOperations Bond credit operations to execute
    /// @dev Security: Only callable by the keyless anchor transactor address
    /// TODO(daniel): remove all validations as node cannot afford reverting.
    function setState(
        State memory _newState,
        LibBondOperation.BondOperation[] memory _bondOperations
    )
        external
        onlyFrom(_ANCHOR_TRANSACTOR)
        nonReentrant
    {
        // Persist synced block data
        if (_newState.anchorBlockNumber > _state.anchorBlockNumber) {
            syncedBlockManager.saveSyncedBlock(
                _newState.anchorBlockNumber, _newState.anchorBlockHash, _newState.anchorStateRoot
            );
        }

        // Process each bond operation
        for (uint256 i; i < _bondOperations.length; ++i) {
            LibBondOperation.BondOperation memory op = _bondOperations[i];
            bondManager.creditBond(op.receiver, op.credit);
        }

        // Atomically update state
        _state = _newState;
    }

    function anchorTransactor() external pure returns (address) {
        return _ANCHOR_TRANSACTOR;
    }
}
