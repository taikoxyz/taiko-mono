// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "src/shared/common/EssentialContract.sol";
import "./LibData.sol";
import "./LibProposing.sol";
import "./LibProving.sol";
import "./LibVerifying.sol";
import "./TaikoEvents.sol";
import "./ITaikoL1.sol";

/// @title TaikoL1
/// @notice This contract serves as the "base layer contract" of the Taiko protocol, providing
/// functionalities for proposing, proving, and verifying blocks. The term "base layer contract"
/// means that although this is usually deployed on L1, it can also be deployed on L2s to create
/// L3s. The contract also handles the deposit and withdrawal of Taiko tokens and Ether.
/// Additionally, this contract doesn't hold any Ether. Ether deposited to L2 are held by the Bridge
/// contract.
/// @dev Labeled in AddressResolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract TaikoL1 is EssentialContract, ITaikoL1, TaikoEvents {
    /// @notice The TaikoL1 state.
    TaikoData.State public state;

    uint256[50] private __gap;

    error L1_FORK_HEIGHT_ERROR();

    modifier whenProvingNotPaused() {
        require(!state.slotB.provingPaused, LibProving.L1_PROVING_PAUSED());
        _;
    }

    modifier emitEventForClient() {
        _;
        emit StateVariablesUpdated(state.slotB);
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    /// @param _genesisBlockHash The block hash of the genesis block.
    /// @param _toPause true to pause the contract by default.
    function init(
        address _owner,
        address _rollupAddressManager,
        bytes32 _genesisBlockHash,
        bool _toPause
    )
        external
        initializer
    {
        __Essential_init(_owner, _rollupAddressManager);
        LibUtils.init(state, _genesisBlockHash);
        if (_toPause) _pause();
    }

    /// @notice This function shall be called by previously deployed contracts.
    function init2() external onlyOwner reinitializer(2) {
        // reset some previously used slots for future reuse
        state.slotB.__reservedB1 = 0;
        state.slotB.__reservedB2 = 0;
        state.slotB.__reservedB3 = 0;
        state.__reserve1 = 0;
    }

    /// @notice This function shall be called by previously deployed contracts.
    function init3() external onlyOwner reinitializer(3) {
        // this value from EssentialContract is no longer used.
        __lastUnpausedAt = 0;
    }

    /// @inheritdoc ITaikoL1
    function proposeBlockV2(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        whenNotPaused
        nonReentrant
        emitEventForClient
        returns (TaikoData.BlockMetadataV2 memory meta_)
    {
        TaikoData.Config memory config = getConfig();
        return LibProposing.proposeBlock(state, config, this, _params, _txList);
    }

    /// @inheritdoc ITaikoL1
    function proposeBlocksV2(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        whenNotPaused
        nonReentrant
        emitEventForClient
        returns (TaikoData.BlockMetadataV2[] memory metaArr_)
    {
        TaikoData.Config memory config = getConfig();
        return LibProposing.proposeBlocks(state, config, this, _paramsArr, _txListArr);
    }

    /// @inheritdoc ITaikoL1
    function proveBlock(
        uint64 _blockId,
        bytes calldata _input
    )
        external
        whenNotPaused
        whenProvingNotPaused
        nonReentrant
        emitEventForClient
    {
        LibProving.proveBlock(state, getConfig(), this, _blockId, _input);
    }

    /// @inheritdoc ITaikoL1
    function proveBlocks(
        uint64[] calldata _blockIds,
        bytes[] calldata _inputs,
        bytes calldata _batchProof
    )
        external
        whenNotPaused
        whenProvingNotPaused
        nonReentrant
        emitEventForClient
    {
        LibProving.proveBlocks(state, getConfig(), this, _blockIds, _inputs, _batchProof);
    }

    /// @inheritdoc ITaikoL1
    function verifyBlocks(uint64 _maxBlocksToVerify)
        external
        whenNotPaused
        whenProvingNotPaused
        nonReentrant
        emitEventForClient
    {
        LibVerifying.verifyBlocks(state, getConfig(), this, _maxBlocksToVerify);
    }

    /// @inheritdoc ITaikoL1
    function pauseProving(bool _pause) external {
        _authorizePause(msg.sender, _pause);
        LibProving.pauseProving(state, _pause);
    }

    /// @inheritdoc ITaikoL1
    function depositBond(uint256 _amount) external whenNotPaused {
        LibBonds.depositBond(state, this, _amount);
    }

    /// @inheritdoc ITaikoL1
    function withdrawBond(uint256 _amount) external whenNotPaused {
        LibBonds.withdrawBond(state, this, _amount);
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

    /// @inheritdoc ITaikoL1
    function getVerifiedBlockProver(uint64 _blockId) external view returns (address prover_) {
        return LibVerifying.getVerifiedBlockProver(state, getConfig(), _blockId);
    }

    /// @notice Gets the details of a block.
    /// @param _blockId Index of the block.
    /// @return blk_ The block.
    function getBlock(uint64 _blockId) external view returns (TaikoData.Block memory blk_) {
        require(_blockId < getConfig().ontakeForkHeight, L1_FORK_HEIGHT_ERROR());

        (TaikoData.BlockV2 memory blk,) = LibUtils.getBlock(state, getConfig(), _blockId);
        blk_ = LibData.blockV2ToV1(blk);
    }

    /// @inheritdoc ITaikoL1
    function getBlockV2(uint64 _blockId) external view returns (TaikoData.BlockV2 memory blk_) {
        require(_blockId >= getConfig().ontakeForkHeight, L1_FORK_HEIGHT_ERROR());

        (blk_,) = LibUtils.getBlock(state, getConfig(), _blockId);
    }

    /// @notice This function will revert if the transition is not found. This function will revert
    /// if the transition is not found.
    /// @param _blockId Index of the block.
    /// @param _parentHash Parent hash of the block.
    /// @return The state transition data of the block.
    function getTransition(
        uint64 _blockId,
        bytes32 _parentHash
    )
        external
        view
        returns (TaikoData.TransitionState memory)
    {
        return LibUtils.getTransitionByParentHash(state, getConfig(), _blockId, _parentHash);
    }

    /// @notice Gets the state transitions for a batch of block. For transition that doesn't exist,
    /// the corresponding transition state will be empty.
    /// @param _blockIds Index of the blocks.
    /// @param _parentHashes Parent hashes of the blocks.
    /// @return The state transition array of the blocks. Note that a transition's state root will
    /// be zero if the block is not a sync-block.
    function getTransitions(
        uint64[] calldata _blockIds,
        bytes32[] calldata _parentHashes
    )
        external
        view
        returns (TaikoData.TransitionState[] memory)
    {
        return LibUtils.getTransitions(state, getConfig(), _blockIds, _parentHashes);
    }

    /// @inheritdoc ITaikoL1
    function getTransition(
        uint64 _blockId,
        uint32 _tid
    )
        external
        view
        returns (TaikoData.TransitionState memory)
    {
        return LibUtils.getTransitionById(
            state, getConfig(), _blockId, SafeCastUpgradeable.toUint24(_tid)
        );
    }

    /// @notice Returns information about the last verified block.
    /// @return blockId_ The last verified block's ID.
    /// @return blockHash_ The last verified block's blockHash.
    /// @return stateRoot_ The last verified block's stateRoot.
    /// @return verifiedAt_ The timestamp this block is proven at.
    function getLastVerifiedBlock()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
    {
        blockId_ = state.slotB.lastVerifiedBlockId;
        (blockHash_, stateRoot_, verifiedAt_) = LibUtils.getBlockInfo(state, getConfig(), blockId_);
    }

    /// @notice Returns information about the last synchronized block.
    /// @return blockId_ The last verified block's ID.
    /// @return blockHash_ The last verified block's blockHash.
    /// @return stateRoot_ The last verified block's stateRoot.
    /// @return verifiedAt_ The timestamp this block is proven at.
    function getLastSyncedBlock()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
    {
        blockId_ = state.slotA.lastSyncedBlockId;
        (blockHash_, stateRoot_, verifiedAt_) = LibUtils.getBlockInfo(state, getConfig(), blockId_);
    }

    /// @notice Gets the state variables of the TaikoL1 contract.
    /// @dev This method can be deleted once node/client stops using it.
    /// @return State variables stored at SlotA.
    /// @return State variables stored at SlotB.
    function getStateVariables()
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

    /// @inheritdoc ITaikoL1
    function getConfig() public pure virtual returns (TaikoData.Config memory) {
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
