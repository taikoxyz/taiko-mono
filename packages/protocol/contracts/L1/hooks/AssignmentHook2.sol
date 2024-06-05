// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./AssignmentHookBase.sol";

/// @title AssignmentHook2
/// @notice A hook that handles prover assignment verification and fee processing.
/// This contract is not proxy-able to reduce gas cost.
/// @custom:security-contact security@taiko.xyz
contract AssignmentHook2 is ReentrancyGuard, AssignmentHookBase, IHook {
    error HOOK_PERMISSION_DENIED();

    address private constant _TAIKO_L1 = 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;

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
        if (msg.sender != _TAIKO_L1) revert HOOK_PERMISSION_DENIED();
        _onBlockProposed(_blk, _meta, _data);
    }

    function _getTaikoTokenAddress() internal view virtual override returns (address) {
        return 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    }
}
