// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EssentialContractStorage } from "src/shared/common/EssentialContractStorage.sol";

/// @title PacayaAnchorStorage
/// @dev This contract is used for maintaining compatibility with the storage layout of the Pacaya anchor.
/// @dev 255 slots were used in Pacaya (EssentialContract, TaikoAnchorDeprecated, etc.).
/// For a full layout of the Pacaya anchor please refer to
/// [the layout table](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.1/packages/protocol/layout/layer2-contracts.md#taikoanchor)
contract PacayaAnchorStorage is EssentialContractStorage {
    /// @dev Slots used by the Pacaya anchor contract itself.
    /// slot0: _blockhashes
    /// slot1: publicInputHash
    /// slot2: parentGasExcess, lastSyncedBlock, parentTimestamp, parentGasTarget
    /// slot3: l1ChainId
    uint256[4] private _pacayaSlots;
}
