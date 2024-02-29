// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "./libs/LibDepositing.sol";
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

    /// @dev Fallback function to receive Ether from Hooks
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

    /// @inheritdoc ITaikoL1
    function proposeBlock(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (TaikoData.BlockMetadata memory meta_, TaikoData.EthDeposit[] memory deposits_)
    {
        TaikoData.Config memory config = getConfig();

        (meta_, deposits_) = LibProposing.proposeBlock(state, config, this, _params, _txList);

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
        nonReentrant
        whenNotPaused
        whenProvingNotPaused
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
        nonReentrant
        whenNotPaused
        whenProvingNotPaused
    {
        LibVerifying.verifyBlocks(state, getConfig(), this, _maxBlocksToVerify);
    }

    /// @notice Pause block proving.
    /// @param _pause True if paused.
    function pauseProving(bool _pause) external {
        _authorizePause(msg.sender);
        LibProving.pauseProving(state, _pause);
    }

    /// @notice Deposits Ether to Layer 2.
    /// @param _recipient Address of the recipient for the deposited Ether on
    /// Layer 2.
    function depositEtherToL2(address _recipient) external payable nonReentrant whenNotPaused {
        LibDepositing.depositEtherToL2(state, getConfig(), this, _recipient);
    }

    /// @inheritdoc EssentialContract
    function unpause() public override {
        super.unpause(); // permission checked inside
        state.slotB.lastUnpausedAt = uint64(block.timestamp);
    }

    /// @notice Checks if Ether deposit is allowed for Layer 2.
    /// @param _amount Amount of Ether to be deposited.
    /// @return true if Ether deposit is allowed, false otherwise.
    function canDepositEthToL2(uint256 _amount) public view returns (bool) {
        return LibDepositing.canDepositEthToL2(state, getConfig(), _amount);
    }

    /// @notice See {LibProposing-isBlobReusable}.
    function isBlobReusable(bytes32 _blobHash) public view returns (bool) {
        return LibProposing.isBlobReusable(state, getConfig(), _blobHash);
    }

    /// @notice Gets the details of a block.
    /// @param _blockId Index of the block.
    /// @return blk_ The block.
    /// @return ts_ The transition used to verify this block.
    function getBlock(uint64 _blockId)
        public
        view
        returns (TaikoData.Block memory blk_, TaikoData.TransitionState memory ts_)
    {
        uint64 slot;
        (blk_, slot) = LibUtils.getBlock(state, getConfig(), _blockId);

        if (blk_.verifiedTransitionId != 0) {
            ts_ = state.transitions[slot][blk_.verifiedTransitionId];
        }
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

    /// @notice Gets the state variables of the TaikoL1 contract.
    /// @return a_ State variables stored at SlotA.
    /// @return b_ State variables stored at SlotB.
    function getStateVariables()
        public
        view
        returns (TaikoData.SlotA memory a_, TaikoData.SlotB memory b_)
    {
        a_ = state.slotA;
        b_ = state.slotB;
    }

    /// @inheritdoc ITaikoL1
    function getConfig() public view virtual override returns (TaikoData.Config memory) {
        // All hard-coded configurations:
        // - treasury: the actual TaikoL2 address.
        // - anchorGasLimit: 250_000 (based on internal devnet, its ~220_000
        // after 256 L2 blocks)
        return TaikoData.Config({
            chainId: 167_008,
            // Assume the block time is 3s, the protocol will allow ~1 month of
            // new blocks without any verification.
            blockMaxProposals: 864_000,
            blockRingBufferSize: 864_100,
            // Can be overridden by the tier config.
            maxBlocksToVerifyPerProposal: 10,
            blockMaxGasLimit: 15_000_000,
            // Each go-ethereum transaction has a size limit of 128KB,
            // and right now txList is still saved in calldata, so we set it
            // to 120KB.
            blockMaxTxListBytes: 120_000,
            blobExpiry: 24 hours,
            blobAllowedForDA: false,
            blobReuseEnabled: false,
            livenessBond: 250e18, // 250 Taiko token
            // ETH deposit related.
            ethDepositRingBufferSize: 1024,
            ethDepositMinCountPerBlock: 8,
            ethDepositMaxCountPerBlock: 32,
            ethDepositMinAmount: 1 ether,
            ethDepositMaxAmount: 10_000 ether,
            ethDepositGas: 21_000,
            ethDepositMaxFee: 1 ether / 10,
            blockSyncThreshold: 16
        });
    }

    function _authorizePause(address)
        internal
        view
        virtual
        override
        onlyFromOwnerOrNamed("chain_pauser")
    { }
}
