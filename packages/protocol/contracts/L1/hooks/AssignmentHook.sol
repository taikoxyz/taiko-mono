// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";
import "./AssignmentHookBase.sol";

/// @title AssignmentHook
/// @notice A hook that handles prover assignment verification and fee processing.
/// @custom:security-contact security@taiko.xyz
contract AssignmentHook is EssentialContract, AssignmentHookBase, IHook {
    uint256[50] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
    }

    /// @inheritdoc IHook
    function onBlockProposed(
        TaikoData.Block calldata _blk,
        TaikoData.BlockMetadata calldata _meta,
        bytes calldata _data
    )
        external
        payable
        nonReentrant
    {
        _onBlockProposed(_blk, _meta, _data);
    }

    function taikoL1() internal view virtual override returns (address) {
        return resolve(LibStrings.B_TAIKO, false);
    }

    function taikoChainId() internal view virtual override returns (uint64) {
        return ITaikoL1(taikoL1()).getConfig().chainId;
    }

    function tkoToken() internal view virtual override returns (address) {
        return resolve(LibStrings.B_TAIKO_TOKEN, false);
    }
}
