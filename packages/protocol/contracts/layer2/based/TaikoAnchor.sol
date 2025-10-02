// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaAnchor.sol";
import { IBondManager as IShastaBondManager } from "./IBondManager.sol";

/// @title TaikoAnchor
/// @notice TaikoAnchor is a smart contract that handles cross-layer message
/// verification and manages EIP-1559 gas pricing for Layer 2 (L2) operations.
/// It is used to anchor the latest L1 block details to L2 for cross-layer
/// communication, manage EIP-1559 parameters for gas pricing, and store
/// verified L1 block information.
/// @dev This contract receives a portion of L2 base fees, while the remainder is directed to
/// L2 block's coinbase address.
/// @custom:security-contact security@taiko.xyz
contract TaikoAnchor is ShastaAnchor {
    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------
    constructor(
        uint48 _livenessBondGwei,
        uint48 _provabilityBondGwei,
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight,
        uint16 _maxCheckpointHistory,
        address _bondManager
    )
        ShastaAnchor(
            _livenessBondGwei,
            _provabilityBondGwei,
            _signalService,
            _pacayaForkHeight,
            _shastaForkHeight,
            _maxCheckpointHistory,
            IShastaBondManager(_bondManager)
        )
    { }

    // -------------------------------------------------------------------
    // External functions
    // -------------------------------------------------------------------

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _l1ChainId The ID of the base layer.
    /// @param _initialGasExcess The initial parentGasExcess.
    function init(
        address _owner,
        uint64 _l1ChainId,
        uint64 _initialGasExcess
    )
        external
        initializer
    {
        __Essential_init(_owner);

        require(_l1ChainId != 0, L2_INVALID_L1_CHAIN_ID());
        require(_l1ChainId != block.chainid, L2_INVALID_L1_CHAIN_ID());
        require(block.chainid > 1, L2_INVALID_L2_CHAIN_ID());
        require(block.chainid <= type(uint64).max, L2_INVALID_L2_CHAIN_ID());

        if (block.number == 0) {
            // This is the case in real L2 genesis
        } else if (block.number == 1) {
            // This is the case in tests
            uint256 parentHeight = block.number - 1;
            _blockhashes[parentHeight] = blockhash(parentHeight);
        } else {
            revert L2_TOO_LATE();
        }

        l1ChainId = _l1ChainId;
        parentGasExcess = _initialGasExcess;
        (publicInputHash,) = _calcPublicInputHash(block.number);
    }
}
