// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../../shared/common/EssentialContract.sol";
import "../../based/ITaikoL1.sol";
import "../libs/LibNames.sol";
import "../libs/LibBlockHeader.sol";
import "../iface/IPreconfServiceManager.sol";
import "../iface/IPreconfTaskManager.sol";

/// @title PreconfTaskManager
/// @custom:security-contact security@taiko.xyz
abstract contract PreconfTaskManager is IPreconfTaskManager, EssentialContract {
    uint256[50] private __gap;

    error SenderNotCurrentPreconfer();

    /// @notice Modifier to update the lookahead and ensure the caller is the current preconfer
    /// @param _lookaheadParams Encoded parameters to set lookahead
    modifier postLookaheadCheckCurrentPreconfer(
        ILookahead.LookaheadParam[] calldata _lookaheadParams
    ) {
        ILookahead lookahead = ILookahead(resolve(LibNames.B_LOOKAHEAD, false));
        // Conditionally post a new lookahead to the lookahead contract
        lookahead.postLookahead(_lookaheadParams);

// TODO: verify current prconfer is check after the look ahead is posted
        require(lookahead.isCurrentPreconfer(msg.sender), SenderNotCurrentPreconfer());

        _;
    }

    /// @notice Initializes the contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @inheritdoc IPreconfTaskManager
    function proposeBlock(
        ILookahead.LookaheadParam[] calldata _lookaheadParams,
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        postLookaheadCheckCurrentPreconfer(_lookaheadParams)
        nonReentrant
        returns (TaikoData.BlockMetadataV2 memory)
    {
        address taiko = resolve(LibNames.B_TAIKO, false);
        return ITaikoL1(taiko).proposeBlockV2(_params, _txList);
    }

    /// @inheritdoc IPreconfTaskManager
    function proposeBlocks(
        ILookahead.LookaheadParam[] calldata _lookaheadParams,
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        postLookaheadCheckCurrentPreconfer(_lookaheadParams)
        nonReentrant
        returns (TaikoData.BlockMetadataV2[] memory)
    {
        address taiko = resolve(LibNames.B_TAIKO, false);
        return ITaikoL1(taiko).proposeBlocksV2(_paramsArr, _txListArr);
    }

    /// @inheritdoc IPreconfTaskManager
    function proveReceiptViolation(
        IReceiptProver.Receipt calldata _receipt,
        bytes calldata _proof
    )
        external
        nonReentrant
    {
        address prover = resolve(LibNames.B_RECEIPT_PROVER, false);
        address preconfer = IReceiptProver(prover).proveReceiptViolation(_receipt, _proof);
        address psm = resolve(LibNames.B_PRECONF_SERVICE_MANAGER, false);
        IPreconfServiceManager(psm).slashOperator(preconfer);
    }
}
