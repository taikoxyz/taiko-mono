// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "./libs/LibProposing.sol";
import "./libs/LibProving.sol";
import "./libs/LibVerifying.sol";
import "./TaikoEvents.sol";
import "./ITaikoL1.sol";

/// @title TaikoL1
/// @notice This contract serves as the "base layer contract" of the Taiko protocol, providing
/// functionalities for proposing, proving, and verifying blocks. The term "base layer contract"
/// means that although this is usually deployed on L1, it can also be deployed on L2s to create
/// L3 "inception layers". The contract also handles the deposit and withdrawal of Taiko tokens
/// and Ether. Additionally, this contract doesn't hold any Ether. Ether deposited to L2 are held
/// by the Bridge contract.
/// @dev Labeled in AddressResolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract TaikoL1 is EssentialContract, ITaikoL1, TaikoEvents {
    /// @notice The TaikoL1 state.
    TaikoData.State public state;

    uint256[50] private __gap;

    error L1_RECEIVE_DISABLED();

    modifier whenProvingNotPaused() {
        if (state.slotB.provingPaused) revert LibProving.L1_PROVING_PAUSED();
        _;
    }

    modifier emitEventForClient() {
        _;
        emit StateVariablesUpdated(state.slotB);
    }

    /// @dev Allows for receiving Ether from Hooks
    receive() external payable {
        if (!inNonReentrant()) revert L1_RECEIVE_DISABLED();
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

    function init2() external onlyOwner reinitializer(2) {
        // reset some previously used slots for future reuse
        state.slotB.__reservedB1 = 0;
        state.slotB.__reservedB2 = 0;
        state.slotB.__reservedB3 = 0;
        state.__reserve1 = 0;
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

        meta_ = LibProposing.proposeBlock(state, config, this, _params, _txList);

        if (LibUtils.shouldVerifyBlocks(config, meta_.id, true) && !state.slotB.provingPaused) {
            LibVerifying.verifyBlocks(state, config, this, config.maxBlocksToVerify);
        }
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
        TaikoData.Config memory config = getConfig();
        LibProving.proveBlock(state, config, this, _blockId, _input);

        if (LibUtils.shouldVerifyBlocks(config, _blockId, false)) {
            LibVerifying.verifyBlocks(state, config, this, config.maxBlocksToVerify);
        }
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

    /// @notice Gets the current bond balance of a given address.
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
        (blk_,) = LibUtils.getBlock(state, getConfig(), _blockId);
    }

    /// @notice Gets the state transition for a specific block.
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
        return LibUtils.getTransition(state, getConfig(), _blockId, _parentHash);
    }

    /// @notice Gets the state transition for a specific block.
    /// @param _blockId Index of the block.
    /// @param _tid The transition id.
    /// @return The state transition data of the block.
    function getTransition(
        uint64 _blockId,
        uint32 _tid
    )
        external
        view
        returns (TaikoData.TransitionState memory)
    {
        return LibUtils.getTransition(state, getConfig(), _blockId, _tid);
    }

    /// @notice Returns information about the last verified block.
    /// @return blockId_ The last verified block's ID.
    /// @return blockHash_ The last verified block's blockHash.
    /// @return stateRoot_ The last verified block's stateRoot.
    function getLastVerifiedBlock()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_)
    {
        blockId_ = state.slotB.lastVerifiedBlockId;
        (blockHash_, stateRoot_) = LibUtils.getBlockInfo(state, getConfig(), blockId_);
    }

    /// @notice Returns information about the last synchronized block.
    /// @return blockId_ The last verified block's ID.
    /// @return blockHash_ The last verified block's blockHash.
    /// @return stateRoot_ The last verified block's stateRoot.
    function getLastSyncedBlock()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_)
    {
        blockId_ = state.slotA.lastSyncedBlockId;
        (blockHash_, stateRoot_) = LibUtils.getBlockInfo(state, getConfig(), blockId_);
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

    /// @inheritdoc EssentialContract
    function unpause() public override {
        super.unpause(); // permission checked inside
        state.slotB.lastUnpausedAt = uint64(block.timestamp);
    }

    /// @inheritdoc ITaikoL1
    function getConfig() public pure virtual override returns (TaikoData.Config memory) {
        // All hard-coded configurations:
        // - treasury: the actual TaikoL2 address.
        // - anchorGasLimit: 250_000 (based on internal devnet, its ~220_000
        // after 256 L2 blocks)
        return TaikoData.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            // If we have 1 block per 12 seconds, then each day there will be 86400/12=7200 blocks.
            // We therefore use 7200 as the base unit to configure blockMaxProposals and
            // blockRingBufferSize.
            blockMaxProposals: 324_000, // = 7200 * 45
            // We give 7200 * 5 = 36000 slots for verifeid blocks in case third party apps will use
            // their data.
            blockRingBufferSize: 360_000, // = 7200 * 50
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
            stateRootSyncInternal: 16,
            maxAnchorHeightOffset: 64,
            basefeeAdjustmentQuotient: 8,
            basefeeSharingPctg: 75
        });
    }

    /// @dev chain_pauser is supposed to be a cold wallet.
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
