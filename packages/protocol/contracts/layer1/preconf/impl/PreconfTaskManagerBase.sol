// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../../shared/common/EssentialContract.sol";
import "../../based/ITaikoL1.sol";
import "../../based/TaikoData.sol";
import "../libs/LibNames.sol";
import "../libs/LibBlockHeader.sol";
import "../iface/ILookahead.sol";
import "../iface/IPreconfServiceManager.sol";
import "../iface/IPreconfTaskManager.sol";

/// @title PreconfTaskManager
/// @custom:security-contact security@taiko.xyz
abstract contract PreconfTaskManagerBase is IPreconfTaskManager, EssentialContract {
    error SenderNotCurrentPreconfer();

    uint256[50] private __gap;

    /// @notice Modifier to update the lookahead and ensure the caller is the current preconfer
    /// @param _lookaheadParams Encoded parameters to set lookahead
    modifier onlyCurrentPreconfer(ILookahead.LookaheadParam[] calldata _lookaheadParams) {
        ILookahead lookahead = ILookahead(resolve(LibNames.B_LOOKAHEAD, false));
        lookahead.postLookahead(_lookaheadParams);

        require(lookahead.isCurrentPreconfer(msg.sender), SenderNotCurrentPreconfer());

        _;
    }

    /// @notice Proposes a Taiko L2 block (version 2)
    /// @param _lookaheadParams parameters to set lookahead
    /// @param _params Block parameters, an encoded BlockParamsV2 object.
    /// @param _txList txList data if calldata is used for DA.
    /// @return meta_ The metadata of the proposed L2 block.
    function newBlockProposal(
        ILookahead.LookaheadParam[] calldata _lookaheadParams,
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        onlyCurrentPreconfer(_lookaheadParams)
        nonReentrant
        returns (TaikoData.BlockMetadataV2 memory)
    {
        ITaikoL1 taiko = ITaikoL1(resolve(LibNames.B_TAIKO, false));
        return taiko.proposeBlockV2(_params, _txList);
    }

    /// @notice Proposes multiple Taiko L2 blocks (version 2)
    /// @param _lookaheadParams parameters to set lookahead
    /// @param _paramsArr A list of encoded BlockParamsV2 objects.
    /// @param _txListArr A list of txList.
    /// @return metaArr_ The metadata objects of the proposed L2 blocks.
    function newBlockProposals(
        ILookahead.LookaheadParam[] calldata _lookaheadParams,
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        onlyCurrentPreconfer(_lookaheadParams)
        nonReentrant
        returns (TaikoData.BlockMetadataV2[] memory)
    {
        ITaikoL1 taiko = ITaikoL1(resolve(LibNames.B_TAIKO, false));
        return taiko.proposeBlocksV2(_paramsArr, _txListArr);
    }
}
