// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "src/shared/common/EssentialContract.sol";
import "./LibProposing.sol";
import "./LibProving.sol";
import "./LibVerifying.sol";
import "./TaikoEvents.sol";
import "./ITaikoL1v3.sol";

/// @title TaikoL1V3
/// @notice This contract serves as the "base layer contract" of the Taiko protocol, providing
/// functionalities for proposing, proving, and verifying blocks. The term "base layer contract"
/// means that although this is usually deployed on L1, it can also be deployed on L2s to create
/// L3s. The contract also handles the deposit and withdrawal of Taiko tokens and Ether.
/// Additionally, this contract doesn't hold any Ether. Ether deposited to L2 are held by the Bridge
/// contract.
/// @dev Labeled in AddressResolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract TaikoL1V3 is EssentialContract, ITaikoL1v3, TaikoEvents {
    /// @notice The TaikoL1 state.
    TaikoData.State public state;

    uint256[50] private __gap;

    /// @dev Emitted to assist with future gas optimizations.
    /// @param isProposeBlock True if measuring gas for proposing a block, false if measuring gas
    /// for proving a block.
    /// @param gasUsed The average gas used per block, including verifications.
    /// @param batchSize The number of blocks proposed or proved.
    event DebugGasPerBlock(bool isProposeBlock, uint256 gasUsed, uint256 batchSize);

    error L1_FORK_HEIGHT_ERROR();

    modifier whenProvingNotPaused() {
        require(!state.slotB.provingPaused, LibProving.L1_PROVING_PAUSED());
        _;
    }

    modifier emitEventForClient() {
        _;
        emit StateVariablesUpdated(state.slotB);
    }

    modifier measureGasUsed(bool _isProposeBlock, uint256 _batchSize) {
        uint256 gas = gasleft();
        _;
        unchecked {
            if (_batchSize > 0) {
                emit DebugGasPerBlock(_isProposeBlock, gas - gasleft() / _batchSize, _batchSize);
            }
        }
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupResolver The {IResolver} used by this rollup.
    /// @param _genesisBlockHash The block hash of the genesis block.
    /// @param _toPause true to pause the contract by default.
    function init(
        address _owner,
        address _rollupResolver,
        bytes32 _genesisBlockHash,
        bool _toPause
    )
        external
        initializer
    {
        __Essential_init(_owner, _rollupResolver);
        LibUtils.init(state, _genesisBlockHash);
        if (_toPause) _pause();
    }

    /// @notice This function shall be called by previously deployed contracts.
    function init2() external onlyOwner reinitializer(2) {
        state.__reserve1 = 0;
    }

    /// @notice This function shall be called by previously deployed contracts.
    function init3() external onlyOwner reinitializer(3) {
        // this value from EssentialContract is no longer used.
        __lastUnpausedAt = 0;
    }

    /// @inheritdoc ITaikoL1v3
    function proposeBlocksV3(bytes[] calldata _paramsArr)
        external
        measureGasUsed(true, _paramsArr.length)
        whenNotPaused
        nonReentrant
        emitEventForClient
        returns (TaikoData.BlockMetadataV2[] memory metaArr_)
    {
        TaikoData.Config memory config = getConfigV3();
        return LibProposing.proposeBlocks(state, config, resolver(), _paramsArr);
    }

    /// @inheritdoc ITaikoL1v3
    function proveBlocksV3(
        uint64[] calldata _blockIds,
        bytes[] calldata _inputs,
        bytes calldata _batchProof
    )
        external
        measureGasUsed(false, _blockIds.length)
        whenNotPaused
        whenProvingNotPaused
        nonReentrant
        emitEventForClient
    {
        LibProving.proveBlocks(state, getConfigV3(), resolver(), _blockIds, _inputs, _batchProof);
    }

    /// @inheritdoc ITaikoL1v3
    function pauseProving(bool _pause) external {
        _authorizePause(msg.sender, _pause);
        LibProving.pauseProving(state, _pause);
    }

    /// @inheritdoc ITaikoL1v3
    function depositBond(uint256 _amount) external payable whenNotPaused {
        LibBonds.depositBond(state, resolver(), _amount);
    }

    /// @inheritdoc ITaikoL1v3
    function withdrawBond(uint256 _amount) external whenNotPaused {
        LibBonds.withdrawBond(state, resolver(), _amount);
    }

    /// @notice Unpauses the contract.
    function unpause() public override whenPaused {
        _authorizePause(msg.sender, false);
        __paused = _FALSE;
        state.slotB.lastUnpausedAt = uint64(block.timestamp);
        emit Unpaused(msg.sender);
    }

    /// @notice Gets the current bond balance of a given address.
    /// @param _user The address of the user.
    /// @return The current bond balance.
    function bondBalanceOf(address _user) external view returns (uint256) {
        return LibBonds.bondBalanceOf(state, _user);
    }

    /// @inheritdoc ITaikoL1v3
    function getVerifiedBlockProver(uint64 _blockId) external view returns (address prover_) {
        return LibVerifying.getVerifiedBlockProver(state, getConfigV3(), _blockId);
    }

    /// @inheritdoc ITaikoL1v3
    function getBlockV3(uint64 _blockId) external view returns (TaikoData.BlockV2 memory blk_) {
        require(_blockId >= getConfigV3().ontakeForkHeight, L1_FORK_HEIGHT_ERROR());

        (blk_,) = LibUtils.getBlock(state, getConfigV3(), _blockId);
    }

    /// @notice This function will revert if the transition is not found. This function will revert
    /// if the transition is not found.
    /// @param _blockId Index of the block.
    /// @param _parentHash Parent hash of the block.
    /// @return The state transition data of the block.
    function getTransitionV3(
        uint64 _blockId,
        bytes32 _parentHash
    )
        external
        view
        returns (TaikoData.TransitionState memory)
    {
        return LibUtils.getTransitionByParentHash(state, getConfigV3(), _blockId, _parentHash);
    }

    /// @notice Gets the state transitions for a batch of block. For transition that doesn't exist,
    /// the corresponding transition state will be empty.
    /// @param _blockIds Index of the blocks.
    /// @param _parentHashes Parent hashes of the blocks.
    /// @return The state transition array of the blocks. Note that a transition's state root will
    /// be zero if the block is not a sync-block.
    function getTransitionsV3(
        uint64[] calldata _blockIds,
        bytes32[] calldata _parentHashes
    )
        external
        view
        returns (TaikoData.TransitionState[] memory)
    {
        return LibUtils.getTransitions(state, getConfigV3(), _blockIds, _parentHashes);
    }

    /// @inheritdoc ITaikoL1v3
    function getTransitionV3(
        uint64 _blockId,
        uint32 _tid
    )
        external
        view
        returns (TaikoData.TransitionState memory)
    {
        return LibUtils.getTransitionById(
            state, getConfigV3(), _blockId, SafeCastUpgradeable.toUint24(_tid)
        );
    }

    /// @notice Returns information about the last verified block.
    /// @return blockId_ The last verified block's ID.
    /// @return blockHash_ The last verified block's blockHash.
    /// @return stateRoot_ The last verified block's stateRoot.
    /// @return verifiedAt_ The timestamp this block is proven at.
    function getLastVerifiedBlockV3()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
    {
        blockId_ = state.slotB.lastVerifiedBlockId;
        (blockHash_, stateRoot_, verifiedAt_) =
            LibUtils.getBlockInfo(state, getConfigV3(), blockId_);
    }

    /// @notice Returns information about the last synchronized block.
    /// @return blockId_ The last verified block's ID.
    /// @return blockHash_ The last verified block's blockHash.
    /// @return stateRoot_ The last verified block's stateRoot.
    /// @return verifiedAt_ The timestamp this block is proven at.
    function getLastSyncedBlockV3()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
    {
        blockId_ = state.slotA.lastSyncedBlockId;
        (blockHash_, stateRoot_, verifiedAt_) =
            LibUtils.getBlockInfo(state, getConfigV3(), blockId_);
    }

    /// @notice Gets the state variables of the TaikoL1 contract.
    /// @dev This method can be deleted once node/client stops using it.
    /// @return State variables stored at SlotA.
    /// @return State variables stored at SlotB.
    function getStateVariablesV3()
        external
        view
        returns (TaikoData.SlotA memory, TaikoData.SlotB memory)
    {
        return (state.slotA, state.slotB);
    }

    /// @notice Returns the timestamp of the last unpaused state.
    /// @return The timestamp of the last unpaused state.
    function lastUnpausedAt() public view override returns (uint64) {
        return state.slotB.lastUnpausedAt;
    }

    /// @notice Retrieves the ID of the L1 block where the most recent L2 block was proposed.
    /// @return The ID of the Li block where the most recent block was proposed.
    function lastProposedIn() external view returns (uint56) {
        return state.slotB.lastProposedIn;
    }

    /// @inheritdoc ITaikoL1v3
    function getConfigV3() public view virtual returns (TaikoData.Config memory) {
        return TaikoData.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            blockMaxProposals: 324_000, // = 7200 * 45
            blockRingBufferSize: 360_000, // = 7200 * 50
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
            stateRootSyncInternal: 16,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000,
                maxGasIssuancePerBlock: 600_000_000 // two minutes
             }),
            ontakeForkHeight: 0
        });
    }

    /// @dev chain watchdog is supposed to be a cold wallet.
    function _authorizePause(
        address,
        bool
    )
        internal
        view
        virtual
        override
        onlyFromOwnerOrNamed(LibStrings.B_CHAIN_WATCHDOG)
    { }
}
