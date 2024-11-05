// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "src/shared/data/LibSharedData.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/common/LibStrings.sol";
import "src/shared/common/LibAddress.sol";
import "src/shared/common/LibMath.sol";
import "src/shared/signal/ISignalService.sol";
import "./LibEIP1559.sol";
import "./LibL2Config.sol";
import "./IBlockHash.sol";

/// @title TaikoL2Deprecated
/// @notice This contract includes deprecated functions whose ABI are still used by client for old
/// blocks.
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoL2Deprecated {
    function anchor(
        bytes32, /*_l1BlockHash*/
        bytes32, /*_l1StateRoot*/
        uint64, /*_l1BlockId*/
        uint32 /*_parentGasUsed */
    )
        external
        notImplemented
    { }

    function getBasefee(
        uint64 _anchorBlockId,
        uint32 _parentGasUsed
    )
        public
        view
        notImplemented
        returns (uint256, /*basefee_*/ uint64 /*parentGasExcess_*/ )
    { }
}
