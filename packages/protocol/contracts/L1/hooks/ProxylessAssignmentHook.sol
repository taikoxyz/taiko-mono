// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./AssignmentHookBase.sol";

/// @title ProxylessAssignmentHook
/// @notice A hook that handles prover assignment verification and fee processing.
/// This contract is not proxy-able to reduce gas cost.
/// @custom:security-contact security@taiko.xyz
contract ProxylessAssignmentHook is ReentrancyGuard, AssignmentHookBase, IHook {
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

    function taikoL1() internal pure virtual override returns (address) {
        return 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
    }

    function tkoToken() internal pure virtual override returns (address) {
        return 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    }
}
