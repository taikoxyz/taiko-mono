// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/based/IProposeBatch.sol";
import "src/layer1/preconf/iface/IPreconfRouter2.sol";
import "src/shared/common/EssentialContract.sol";
import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/layer1/preconf/iface/IPreconfWhitelist.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "src/layer1/preconf/libs/LibMerkleTree.sol";
import "@eth-fabric/urc/IRegistry.sol";

/// @title PreconfRouter2
/// @custom:security-contact security@taiko.xyz
contract PreconfRouter2 is IPreconfRouter2, EssentialContract {
    ILookaheadStore public immutable lookaheadStore;
    IPreconfWhitelist public immutable preconfWhitelist;
    IProposeBatch public immutable proposeBatchEntrypoint;
    IRegistry public immutable urc;
    address public immutable preconfSlasher;
    address public immutable fallbackPreconfer;

    constructor(
        address _resolver,
        address _lookaheadStore,
        address _preconfWhitelist,
        address _proposeBatchEntrypoint,
        address _preconfSlasher,
        address _urc,
        address _fallbackPreconfer
    )
        EssentialContract(_resolver)
    {
        lookaheadStore = ILookaheadStore(_lookaheadStore);
        preconfWhitelist = IPreconfWhitelist(_preconfWhitelist);
        proposeBatchEntrypoint = IProposeBatch(_proposeBatchEntrypoint);
        preconfSlasher = _preconfSlasher;
        urc = IRegistry(_urc);
        fallbackPreconfer = _fallbackPreconfer;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IPreconfRouter2
    function proposeBatch(
        bytes calldata _lookahead,
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    {
        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        bytes32 lookaheadRoot = lookaheadStore.getLookaheadRoot(epochTimestamp);

        if (lookaheadRoot == keccak256(abi.encode(epochTimestamp))) {
            _validateWhitelistPreconfer();
        } else {
            (ILookaheadStore.LookaheadLeaf memory lookaheadLeaf, bytes32[] memory proof) =
                abi.decode(_lookahead, (ILookaheadStore.LookaheadLeaf, bytes32[]));

            _validateLookaheadPreconfer(lookaheadLeaf, lookaheadRoot, proof);
        }

        // Both TaikoInbox and TaikoWrapper implement the same ABI for IProposeBatch.
        (info_, meta_) = proposeBatchEntrypoint.v4ProposeBatch(_params, _txList);

        // Verify that the sender had set itself as the proposer
        require(info_.proposer == msg.sender, ProposerIsNotPreconfer());
    }

    // Internal functions ----------------------------------------------------------------------

    function _validateWhitelistPreconfer() internal view {
        address preconfer = preconfWhitelist.getOperatorForCurrentEpoch();
        if (preconfer != address(0)) {
            require(msg.sender == preconfer, NotPreconfer());
        } else if (fallbackPreconfer != address(0)) {
            require(msg.sender == fallbackPreconfer, NotFallbackPreconfer());
        }
    }

    function _validateLookaheadPreconfer(
        ILookaheadStore.LookaheadLeaf memory _lookaheadLeaf,
        bytes32 _lookaheadRoot,
        bytes32[] memory _proof
    )
        internal
        view
    {
        // Validate the lookahead against the retrieved lookahead root
        require(
            LibMerkleTree.verifyProof(
                _lookaheadRoot, keccak256(abi.encode(_lookaheadLeaf)), _lookaheadLeaf.index, _proof
            ),
            InvalidLookaheadProof()
        );

        // Validate that the sender is the preconfer for the current precofing period
        require(msg.sender == _lookaheadLeaf.committer, ProposerIsNotPreconfer());

        // Validate the preconfing period
        require(
            block.timestamp > _lookaheadLeaf.prevTimestamp
                && block.timestamp < _lookaheadLeaf.timestamp,
            InvalidLookaheadTimestamp()
        );

        // Ensure that the associated operator is active and opted into the preconf slasher
        IRegistry.OperatorData memory operatorData =
            urc.getOperatorData(_lookaheadLeaf.operatorRegistrationRoot);
        require(operatorData.slashedAt == 0, OperatorIsSlashed());
        require(operatorData.unregisteredAt == 0, OperatorIsUnregistered());
        require(
            urc.isOptedIntoSlasher(_lookaheadLeaf.operatorRegistrationRoot, preconfSlasher),
            OperatorIsNotOptedIn()
        );
    }
}
