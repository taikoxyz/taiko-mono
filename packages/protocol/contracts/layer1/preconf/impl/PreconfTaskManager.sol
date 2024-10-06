// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../../shared/common/EssentialContract.sol";
import "../../based/ITaikoL1.sol";
import "../../based/TaikoData.sol";
import "../libs/LibNames.sol";
import "../iface/ILookahead.sol";
import "../iface/IPreconfServiceManager.sol";
import "../iface/IPreconfTaskManager.sol";

/// @title PreconfTaskManager.sol
/// @custom:security-contact security@taiko.xyz
contract PreconfTaskManager is IPreconfTaskManager, EssentialContract {
    using ECDSA for bytes32;

    error SenderNotCurrentPreconfer();

    uint256[50] private __gap;

    modifier onlyFromCurrentPreconfer() {
        ILookahead lookahead = ILookahead(resolve(LibNames.B_LOOKAHEAD, false));
        require(lookahead.isCurrentPreconfer(msg.sender), SenderNotCurrentPreconfer());
        _;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
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
        ITaikoL1 taiko = ITaikoL1(resolve(LibNames.B_TAIKO, false));
        return taiko.proposeBlockV2(_params, _txList);
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
        ITaikoL1 taiko = ITaikoL1(resolve(LibNames.B_TAIKO, false));
        return taiko.proposeBlocksV2(_paramsArr, _txListArr);
    }
}
