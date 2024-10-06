// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../shared/common/EssentialContract.sol";
import "../based/ITaikoL1.sol";
import "./LibNames.sol";
import "./ILookahead.sol";
import "./IPreconfTaskManager.sol";

/// @title PreconfTaskManager.sol
/// @custom:security-contact security@taiko.xyz
contract PreconfTaskManager is IPreconfTaskManager, EssentialContract {
    error SenderNotCurrentPreconfer();

    modifier onlyFromCurrentPreconfer() {
        require(_lookahead().isCurrentPreconfer(msg.sender), SenderNotCurrentPreconfer());
        _;
    }

    /// @notice Proposes a Taiko L2 block (version 2)
    /// @param _params Block parameters, an encoded BlockParamsV2 object.
    /// @param _txList txList data if calldata is used for DA.
    /// @return meta_ The metadata of the proposed L2 block.
    function newBlockProposal(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        onlyFromCurrentPreconfer
        nonReentrant
        returns (TaikoData.BlockMetadataV2 memory)
    {
        return _taikoL1().proposeBlockV2(_params, _txList);
    }

    /// @notice Proposes multiple Taiko L2 blocks (version 2)
    /// @param _paramsArr A list of encoded BlockParamsV2 objects.
    /// @param _txListArr A list of txList.
    /// @return metaArr_ The metadata objects of the proposed L2 blocks.
    function newBlockProposals(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        onlyFromCurrentPreconfer
        nonReentrant
        returns (TaikoData.BlockMetadataV2[] memory)
    {
        return _taikoL1().proposeBlocksV2(_paramsArr, _txListArr);
    }

    function _taikoL1() private view returns (ITaikoL1) {
        return ITaikoL1(resolve(LibNames.B_TAIKO, false));
    }

    function _lookahead() private view returns (ILookahead) {
        return ILookahead(resolve(LibNames.B_LOOKAHEAD, false));
    }
}
