// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../common/EssentialContractStorage.sol";

/// @title PacayaSignalServiceStorage
/// @dev This contract is used for maintaining compatibility with the storage layout of the Pacaya
/// signal service.
/// @dev 254 slots [0..253] were used in Pacaya. For a full layout of the Pacaya signal service
/// please refer to [the layout table]
// solhint-disable-next-line max-line-length
/// (https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.1/packages/protocol/layout/layer1-contracts.md#signalservice)
contract PacayaSignalServiceStorage is EssentialContractStorage {
    /// @dev Slots used by the Pacaya signal service contract itself.
    uint256[3] private _slotsUsedByPacaya;
}
