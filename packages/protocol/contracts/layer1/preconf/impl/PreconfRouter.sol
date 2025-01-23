// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IPreconfRouter.sol";
import "../iface/IPreconfWhitelist.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/common/EssentialContract.sol";

/// @title PreconfRouter
/// @custom:security-contact security@taiko.xyz
contract PreconfRouter is EssentialContract, IPreconfRouter {
    mapping(bytes32 => ForcedTx) public forcedTxLists;

    uint256 public pendingForcedTxHashes;
    
    uint256 public inclusionWindow;

    uint256 public baseStakeAmount;

    uint256[46] private __gap;

    constructor(address _resolver, uint256 _inclusionWindow, uint256 _baseStakeAmount) EssentialContract(_resolver) {
        inclusionWindow = _inclusionWindow;
        baseStakeAmount = _baseStakeAmount;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function updateBaseStakeAmount(uint256 _newBaseStakeAmount) external onlyOwner {
        baseStakeAmount = _newBaseStakeAmount;
    }

    function getRequiredStakeAmount() public view returns (uint256) {
        return (2 ** pendingForcedTxHashes).max(4096) * baseStakeAmount;
        return baseStakeAmount * multiplier;
    }

    function storeForcedTx(bytes calldata _txList) payable external {
        uint256 requiredStake = getRequiredStakeAmount();
        require(msg.value >= requiredStake, InsufficientStakeAmount());

        bytes32 txListHash = keccak256(_txList);
        require(forcedTxLists[txListHash].timestamp == 0, ForcedTxListAlreadyStored());

        forcedTxLists[txListHash] = ForcedTx({
            txList: _txList,
            timestamp: block.timestamp,
            included: false,
            stakeAmount: msg.value
        });

        pendingForcedTxHashes++;

        emit ForcedTxStored(_txList, block.timestamp);
    }

    /// @inheritdoc IPreconfRouter
    function proposePreconfedBlocks(
        bytes calldata,
        bytes calldata _batchParams,
        bytes calldata _batchTxList,
        bool force
    )
        external
        returns (ITaikoInbox.BatchMetadata memory meta_)
    {
        bytes32 forcedTxListHash = keccak256(_batchTxList);
        
        // Sender must be the selected operator for the epoch, or able to propose a forced txList
        // after the inclusion window has expired
        address selectedOperator =
            IPreconfWhitelist(resolve(LibStrings.B_PRECONF_WHITELIST, false)).getOperatorForEpoch();
        
        if(force) {
            require(msg.sender == selectedOperator || canProposeFallback(forcedTxListHash), NotTheOperator());
        } else {
            require(msg.sender == selectedOperator, NotTheOperator());
        }

         if (force) {
            require(forcedTxLists[forcedTxListHash].timestamp != 0, ForcedTxListHashNotFound());
            require(!forcedTxLists[forcedTxListHash].included, ForcedTxListAlreadyIncluded());

            // Pay out the stake to the proposer
            LibAddress.sendEtherAndVerify(msg.sender, forcedTxLists[forcedTxListHash].stakeAmount);

            pendingForcedTxHashes--;

            forcedTxLists[forcedTxListHash].included = true;
        }


        // Call the proposeBatch function on the TaikoInbox
        address taikoInbox = resolve(LibStrings.B_TAIKO, false);
        meta_ = ITaikoInbox(taikoInbox).proposeBatch(_batchParams, _batchTxList);

        // Verify that the sender had set itself as the proposer
        require(meta_.proposer == msg.sender, ProposerIsNotTheSender());
    }

     function canProposeFallback(bytes32 _forcedTxHash) public view returns (bool) {
        return block.timestamp > forcedTxLists[_forcedTxHash].timestamp + inclusionWindow &&
            !forcedTxLists[_forcedTxHash].included;
    }
}
