// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

/**
 * @author dantaik <dan@taiko.xyz>
 * @notice Interface to set and get an address for a name.
 */
interface IHeaderSync {
    event HeaderSynced(
        uint256 indexed height,
        uint256 indexed srcHeight,
        bytes32 srcHash
    );

    function getSyncedHeader(uint256 number) external view returns (bytes32);

    function getLatestSyncedHeader() external view returns (bytes32);
}
