// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibEtnaRewards } from "src/shared/libs/LibEtnaRewards.sol";
import { LibTrieProof } from "src/shared/libs/LibTrieProof.sol";

/// @title L2FeeVault
/// @notice Pays the base fees committed by landed Etna batches to their L2 reward recipients.
/// @dev Deployed directly in a new genesis at the execution client's treasury address. Execution
/// layer credits execute no code. A receipt in the fixed L1 Inbox authenticates the only payout;
/// extra or forced Ether creates no entitlement. This contract has no owner or upgrade route.
/// @custom:security-contact security@taiko.xyz
contract L2FeeVault {
    /// @notice The system contract that exposes authenticated L1 state roots by timestamp.
    address public constant ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    /// @notice The L1 chain on which reward receipts are recorded.
    uint256 public immutable l1ChainId;

    /// @notice The L1 Inbox whose storage commits reward receipts.
    address public immutable l1Inbox;

    bool private _entered;

    /// @notice Whether the batch has already paid its authenticated reward.
    mapping(bytes32 batchId => bool claimed) public claimed;

    /// @notice Emitted when a batch's authenticated reward is claimed.
    /// @param batchId The identifier of the landed batch.
    /// @param recipient The recipient committed in the L1 receipt.
    /// @param amount The committed base fee amount in wei.
    event RewardClaimed(bytes32 indexed batchId, address indexed recipient, uint256 amount);

    /// @notice Fixes the chain and Inbox that authenticate all claims.
    /// @param _l1ChainId The nonzero L1 chain ID.
    /// @param _l1Inbox The nonzero L1 Inbox address.
    constructor(uint256 _l1ChainId, address _l1Inbox) {
        require(_l1ChainId != 0 && _l1Inbox != address(0), InvalidL1Identity());
        l1ChainId = _l1ChainId;
        l1Inbox = _l1Inbox;
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Pays a landed batch's base fees exactly once to its committed L2 recipient.
    /// @dev Anyone may submit the proof. The trusted system root authenticates both the L1 Inbox
    /// account and receipt storage slot. Failed transfers revert the claim so it can be retried.
    /// Zero-amount receipts are consumed without calling the recipient.
    /// @param _receipt The landed batch receipt committed in the L1 Inbox.
    /// @param _anchorTimestamp The timestamp used to retrieve the authenticated L1 state root.
    /// @param _accountProof The nonempty L1 Inbox account inclusion proof.
    /// @param _storageProof The inclusion proof for the batch's receipt commitment.
    function claim(
        LibEtnaRewards.Receipt calldata _receipt,
        uint256 _anchorTimestamp,
        bytes[] calldata _accountProof,
        bytes[] calldata _storageProof
    )
        external
    {
        require(!_entered, ReentrantClaim());
        _entered = true;
        require(
            _receipt.l1ChainId == l1ChainId && _receipt.l2ChainId == block.chainid
                && _receipt.inbox == l1Inbox && _receipt.lastHeight > _receipt.parentHeight
                && _receipt.l2RewardRecipient != address(0),
            InvalidReceipt()
        );
        require(_accountProof.length != 0, EmptyAccountProof());

        bytes32 id = LibEtnaRewards.batchId(_receipt);
        require(!claimed[id], AlreadyClaimed());
        // EIP-4788 takes a raw 32-byte timestamp, with no function selector.
        (bool ok, bytes memory data) = ROOTS.staticcall(abi.encode(_anchorTimestamp));
        require(ok && data.length == 32, InvalidAnchorRoot());
        bytes32 root = abi.decode(data, (bytes32));
        require(root != bytes32(0), InvalidAnchorRoot());
        LibTrieProof.verifyMerkleProof(
            root,
            l1Inbox,
            LibEtnaRewards.receiptSlot(id),
            LibEtnaRewards.commitment(_receipt),
            _accountProof,
            _storageProof
        );

        claimed[id] = true;
        if (_receipt.baseFeeAmount != 0) {
            (ok,) = _receipt.l2RewardRecipient.call{ value: _receipt.baseFeeAmount }("");
            require(ok, RewardTransferFailed());
        }
        _entered = false;
        emit RewardClaimed(id, _receipt.l2RewardRecipient, _receipt.baseFeeAmount);
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error AlreadyClaimed();
    error EmptyAccountProof();
    error InvalidAnchorRoot();
    error InvalidL1Identity();
    error InvalidReceipt();
    error ReentrantClaim();
    error RewardTransferFailed();
}
