// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ForkRouter } from "src/shared/fork-router/ForkRouter.sol";

/// @notice Interface exposing the legacy Pacaya anchor functionality used pre-fork.
interface IPacayaAnchorLegacy {
    struct BaseFeeConfig {
        uint8 adjustmentQuotient;
        uint8 sharingPctg;
        uint32 gasIssuancePerSecond;
        uint64 minGasExcess;
        uint32 maxGasIssuancePerBlock;
    }

    function anchorV3(
        uint64 _anchorBlockId,
        bytes32 _anchorStateRoot,
        uint32 _parentGasUsed,
        BaseFeeConfig calldata _baseFeeConfig,
        bytes32[] calldata _signalSlots
    )
        external;

    function getBasefeeV2(
        uint32 _parentGasUsed,
        uint64 _blockTimestamp,
        BaseFeeConfig calldata _baseFeeConfig
    )
        external
        view
        returns (uint256, uint64, uint64);

    function getBlockHash(uint256 _blockId) external view returns (bytes32);

    function skipFeeCheck() external pure returns (bool);

    function publicInputHash() external view returns (bytes32);

    function parentGasExcess() external view returns (uint64);

    function lastSyncedBlock() external view returns (uint64);

    function parentTimestamp() external view returns (uint64);

    function parentGasTarget() external view returns (uint64);

    function signalService() external view returns (address);

    function pacayaForkHeight() external view returns (uint64);
}

/// @title AnchorForkRouter
/// @notice Routes calls between the Pacaya and Shasta anchor implementations.
/// @custom:security-contact security@taiko.xyz
contract AnchorForkRouter is ForkRouter {
    constructor(address _oldFork, address _newFork) ForkRouter(_oldFork, _newFork) { }

    function shouldRouteToOldFork(bytes4 _selector) public pure override returns (bool) {
        return _selector == IPacayaAnchorLegacy.anchorV3.selector
            || _selector == IPacayaAnchorLegacy.getBasefeeV2.selector
            || _selector == IPacayaAnchorLegacy.getBlockHash.selector
            || _selector == IPacayaAnchorLegacy.skipFeeCheck.selector
            || _selector == IPacayaAnchorLegacy.publicInputHash.selector
            || _selector == IPacayaAnchorLegacy.parentGasExcess.selector
            || _selector == IPacayaAnchorLegacy.lastSyncedBlock.selector
            || _selector == IPacayaAnchorLegacy.parentTimestamp.selector
            || _selector == IPacayaAnchorLegacy.parentGasTarget.selector
            || _selector == IPacayaAnchorLegacy.signalService.selector
            || _selector == IPacayaAnchorLegacy.pacayaForkHeight.selector;
    }
}
