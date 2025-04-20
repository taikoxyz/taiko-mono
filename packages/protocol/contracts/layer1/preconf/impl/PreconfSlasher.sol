// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "urc/src/ISlasher.sol";
import "src/shared/common/EssentialContract.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "../iface/IPreconfCommitment.sol";

contract PreconfSlasher is EssentialContract, IPreconfCommitment, ISlasher {
    ITaikoInbox public immutable inbox;
    uint256 public immutable chainId;
    uint256 public immutable penaltyAmountWei = 0.1 ether;
    mapping(bytes32 commitmentHash => bool slahsed) public slashed;

    error BlockHashesMatch();
    error ChainIdMismatch();
    error ConditionsNotMet();
    error AlreadySlashed();

    uint256[50] private __gap;

    constructor(
        address _inbox,
        uint256 _penaltyAmountWei
    )
        nonZeroAddr(_inbox)
        nonZeroValue(_penaltyAmountWei)
        EssentialContract(address(0))
    {
        inbox = ITaikoInbox(_inbox);
        chainId = inbox.v4GetConfig().chainId;
        penaltyAmountWei = _penaltyAmountWei;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc ISlasher
    function slash(
        Delegation calldata delegation,
        Commitment calldata commitment,
        bytes calldata evidence,
        address challenger
    )
        external
        returns (uint256 slashAmountWei)
    { // TODO
    }

    /// @inheritdoc ISlasher
    function slashFromOptIn(
        Commitment calldata commitment,
        bytes calldata evidence,
        address challenger
    )
        external
        nonReentrant
        returns (uint256)
    {
        bytes32 hash = keccak256(abi.encode(commitment));
        require(!slashed[hash], AlreadySlashed());
        slashed[hash] = true;

        // TODO: implement this function, the following is just a demo of ideas
        PreconfCommitment memory pc = abi.decode(commitment.payload, (PreconfCommitment));
        require(chainId == pc.chainId, ChainIdMismatch());

        bytes32 blockHash = getTaikoBlockHash(pc.batchId, pc.blockId, evidence);
        require(blockHash != pc.blockHash, BlockHashesMatch());

        require(evaluateConditions(pc.conditions), ConditionsNotMet());

        return penaltyAmountWei;
    }

    /// @dev Checks the block has been verified and returns the block's hash.
    function getTaikoBlockHash(
        uint256 _batchId,
        uint256 _blockId,
        bytes calldata _evidence
    )
        internal
        view
        virtual
        returns (bytes32)
    { }

    function evaluateConditions(PreconfConditions memory _conditions)
        internal
        view
        virtual
        returns (bool)
    {
        // TODO
        return true;
    }
}
