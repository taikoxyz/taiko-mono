// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "./libs/LibProposing.sol";
import "./libs/LibProving.sol";
import "./libs/LibVerifying.sol";
import "./ITaikoL1.sol";
import "./TaikoErrors.sol";
import "./TaikoEvents.sol";

/// @title TaikoL1
/// @notice This contract serves as the "base layer contract" of the Taiko protocol, providing
/// functionalities for proposing, proving, and verifying blocks. The term "base layer contract"
/// means that although this is usually deployed on L1, it can also be deployed on L2s to create
/// L3 "inception layers". The contract also handles the deposit and withdrawal of Taiko tokens
/// and Ether. Additionally, this contract doesn't hold any Ether. Ether deposited to L2 are held
/// by the Bridge contract.
/// @dev Labeled in AddressResolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract TaikoL1 is EssentialContract, ITaikoL1, TaikoEvents, TaikoErrors {
    /// @notice The TaikoL1 state.
    TaikoData.State public state;

    uint256[50] private __gap;

    modifier whenProvingNotPaused() {
        if (state.slotB.provingPaused) revert L1_PROVING_PAUSED();
        _;
    }

    modifier emitEventForClient() {
        _;
        LibVerifying.emitEventForClient(state);
    }

    /// @dev Allows for receiving Ether from Hooks
    receive() external payable {
        if (!_inNonReentrant()) revert L1_RECEIVE_DISABLED();
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _genesisBlockHash The block hash of the genesis block.
    function init(
        address _owner,
        address _addressManager,
        bytes32 _genesisBlockHash
    )
        external
        initializer
    {
        __Essential_init(_owner, _addressManager);
        LibVerifying.init(state, getConfig(), _genesisBlockHash);
    }

    function init2() external onlyOwner reinitializer(2) {
        // reset some previously used slots for future reuse
        state.slotB.__reservedB1 = 0;
        state.slotB.__reservedB2 = 0;
        state.slotB.__reservedB3 = 0;
        state.__reserve1 = 0;
    }

    /// @inheritdoc ITaikoL1
    function proposeBlock(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        payable
        whenNotPaused
        nonReentrant
        emitEventForClient
        returns (TaikoData.BlockMetadata memory meta_, TaikoData.EthDeposit[] memory deposits_)
    {
        TaikoData.Config memory config = getConfig();
        (meta_, deposits_) = LibProposing.proposeBlock(
            state, config, this, _params, _txList, _checkEOAForCalldataDA()
        );

        if (!state.slotB.provingPaused) {
            LibVerifying.verifyBlocks(state, config, this, config.maxBlocksToVerifyPerProposal);
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
        (
            TaikoData.BlockMetadata memory meta,
            TaikoData.Transition memory tran,
            TaikoData.TierProof memory proof
        ) = abi.decode(_input, (TaikoData.BlockMetadata, TaikoData.Transition, TaikoData.TierProof));

        if (_blockId != meta.id) revert L1_INVALID_BLOCK_ID();

        TaikoData.Config memory config = getConfig();

        uint8 maxBlocksToVerify = LibProving.proveBlock(state, config, this, meta, tran, proof);

        LibVerifying.verifyBlocks(state, config, this, maxBlocksToVerify);
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

    /// @notice Pause block proving.
    /// @param _pause True if paused.
    function pauseProving(bool _pause) external {
        _authorizePause(msg.sender, _pause);
        LibProving.pauseProving(state, _pause);
    }

    /// @inheritdoc EssentialContract
    function unpause() public override {
        super.unpause(); // permission checked inside
        state.slotB.lastUnpausedAt = uint64(block.timestamp);
    }

    /// @notice Gets the details of a block.
    /// @param _blockId Index of the block.
    /// @return blk_ The block.
    function getBlock(uint64 _blockId) public view returns (TaikoData.Block memory blk_) {
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
        public
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
        public
        view
        returns (TaikoData.TransitionState memory)
    {
        return LibUtils.getTransition(state, getConfig(), _blockId, _tid);
    }
    /// @notice Gets the state variables of the TaikoL1 contract.
    /// @dev This method can be deleted once node/client stops using it.
    /// @return State variables stored at SlotA.
    /// @return State variables stored at SlotB.

    function getStateVariables()
        public
        view
        returns (TaikoData.SlotA memory, TaikoData.SlotB memory)
    {
        return (state.slotA, state.slotB);
    }

    /// @notice Gets SlotA
    /// @return  State variables stored at SlotA.
    function slotA() public view returns (TaikoData.SlotA memory) {
        return state.slotA;
    }

    /// @notice Gets SlotB
    /// @return  State variables stored at SlotB.
    function slotB() public view returns (TaikoData.SlotB memory) {
        return state.slotB;
    }

    /// @inheritdoc ITaikoL1
    function getConfig() public view virtual override returns (TaikoData.Config memory) {
        // All hard-coded configurations:
        // - treasury: the actual TaikoL2 address.
        // - anchorGasLimit: 250_000 (based on internal devnet, its ~220_000
        // after 256 L2 blocks)
        return TaikoData.Config({
            chainId: LibNetwork.TAIKO,
            // Assume the block time is 3s, the protocol will allow ~90 days of
            // new blocks without any verification.
            blockMaxProposals: 3_000_000,
            blockRingBufferSize: 3_010_000,
            // Can be overridden by the tier config.
            maxBlocksToVerifyPerProposal: 10,
            // This value is set based on `gasTargetPerL1Block = 15_000_000 * 4` in TaikoL2.
            // We use 8x rather than 4x here to handle the scenario where the average number of
            // Taiko blocks proposed per Ethereum block is smaller than 1.
            blockMaxGasLimit: 240_000_000,
            livenessBond: 250e18, // 250 Taiko token
            blockSyncThreshold: 16
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

    function _checkEOAForCalldataDA() internal pure virtual returns (bool) {
        return true;
    }
}
