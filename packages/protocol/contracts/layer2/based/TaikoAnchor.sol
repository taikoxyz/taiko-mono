// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoAnchorShasta.sol";

contract TaikoAnchor is TaikoAnchorShasta {
    constructor(
        address _resolver,
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight
    )
        TaikoAnchorShasta(_resolver, _signalService, _pacayaForkHeight, _shastaForkHeight)
    { }

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
