// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

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
/// @custom:security-contact security@taiko.xyz
/// @dev Labeled in AddressResolver as "taiko"
/// @notice This contract serves as the "base layer contract" of the Taiko
/// protocol, providing functionalities for proposing, proving, and verifying
/// blocks. The term "base layer contract" means that although this is usually
/// deployed on L1, it can also be deployed on L2s to create L3s ("inception
/// layers"). The contract also handles the deposit and withdrawal of Taiko
/// tokens and Ether.
/// This contract doesn't hold any Ether. Ether deposited to L2 are held by the Bridge contract.
contract TaikoL1 is EssentialContract, ITaikoL1, ITierProvider, TaikoEvents, TaikoErrors {
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
        bytes calldata params,
        bytes calldata txList
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (
            TaikoData.BlockMetadata memory rMeta,
            TaikoData.EthDeposit[] memory rDepositsProcessed
        )
    {
        TaikoData.Config memory config = getConfig();

        (rMeta, rDepositsProcessed) = LibProposing.proposeBlock(state, config, this, params, txList);

        if (!state.slotB.provingPaused) {
            _verifyBlocks(config, config.maxBlocksToVerifyPerProposal);
        }
    }

    /// @inheritdoc ITaikoL1
    function proveBlock(
        uint64 blockId,
        bytes calldata input
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
        ) = abi.decode(input, (TaikoData.BlockMetadata, TaikoData.Transition, TaikoData.TierProof));

        if (blockId != meta.id) revert L1_INVALID_BLOCK_ID();

        TaikoData.Config memory config = getConfig();

        uint8 maxBlocksToVerify = LibProving.proveBlock(state, config, this, meta, tran, proof);

        _verifyBlocks(config, maxBlocksToVerify);
    }

    /// @inheritdoc ITaikoL1
    function verifyBlocks(uint64 maxBlocksToVerify) external nonReentrant whenNotPaused {
        _verifyBlocks(getConfig(), maxBlocksToVerify);
    }

    /// @notice Pause block proving.
    /// @param pause True if paused.
    function pauseProving(bool pause) external {
        _authorizePause(msg.sender);
        LibProving.pauseProving(state, pause);
    }

    /// @notice Deposits Ether to Layer 2.
    /// @param recipient Address of the recipient for the deposited Ether on
    /// Layer 2.
    function depositEtherToL2(address recipient) external payable nonReentrant whenNotPaused {
        LibDepositing.depositEtherToL2(state, getConfig(), this, recipient);
    }

    function unpause() public override {
        super.unpause(); // permission checked inside
        state.slotB.lastUnpausedAt = uint64(block.timestamp);
    }

    /// @notice Checks if Ether deposit is allowed for Layer 2.
    /// @param amount Amount of Ether to be deposited.
    /// @return true if Ether deposit is allowed, false otherwise.
    function canDepositEthToL2(uint256 amount) public view returns (bool) {
        return LibDepositing.canDepositEthToL2(state, getConfig(), amount);
    }

    function isBlobReusable(bytes32 blobHash) public view returns (bool) {
        return LibProposing.isBlobReusable(state, getConfig(), blobHash);
    }

    /// @notice Gets the details of a block.
    /// @param blockId Index of the block.
    /// @return rBlk The block.
    /// @return rTs The transition used to verify this block.
    function getBlock(uint64 blockId)
        public
        view
        returns (TaikoData.Block memory rBlk, TaikoData.TransitionState memory rTs)
    {
        uint64 slot;
        (rBlk, slot) = LibUtils.getBlock(state, getConfig(), blockId);

        if (rBlk.verifiedTransitionId != 0) {
            rTs = state.transitions[slot][rBlk.verifiedTransitionId];
        }
    }

    /// @notice Gets the state transition for a specific block.
    /// @param blockId Index of the block.
    /// @param parentHash Parent hash of the block.
    /// @return TransitionState The state transition data of the block.
    function getTransition(
        uint64 blockId,
        bytes32 parentHash
    )
        public
        view
        returns (TaikoData.TransitionState memory)
    {
        return LibUtils.getTransition(state, getConfig(), blockId, parentHash);
    }

    /// @notice Gets the state variables of the TaikoL1 contract.
    /// @return slotA State variables stored at SlotA.
    /// @return slotB State variables stored at SlotB.
    function getStateVariables()
        public
        view
        returns (TaikoData.SlotA memory, TaikoData.SlotB memory)
    {
        return (state.slotA, state.slotB);
    }

    /// @notice Retrieves the configuration for a specified tier.
    /// @param tierId ID of the tier.
    /// @return Tier struct containing the tier's parameters. This
    /// function will revert if the tier is not supported.
    function getTier(uint16 tierId)
        public
        view
        virtual
        override
        returns (ITierProvider.Tier memory)
    {
        return ITierProvider(resolve("tier_provider", false)).getTier(tierId);
    }

    /// @inheritdoc ITierProvider
    function getTierIds() public view override returns (uint16[] memory ids) {
        ids = ITierProvider(resolve("tier_provider", false)).getTierIds();
        if (ids.length >= type(uint8).max) revert L1_TOO_MANY_TIERS();
    }

    /// @inheritdoc ITierProvider
    function getMinTier(uint256 rand) public view override returns (uint16) {
        return ITierProvider(resolve("tier_provider", false)).getMinTier(rand);
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

    function isConfigValid() public view returns (bool) {
        return LibVerifying.isConfigValid(getConfig());
    }

    function _verifyBlocks(
        TaikoData.Config memory config,
        uint64 maxBlocksToVerify
    )
        internal
        whenProvingNotPaused
    {
        LibVerifying.verifyBlocks(state, config, this, maxBlocksToVerify);
    }

    function _authorizePause(address)
        internal
        view
        virtual
        override
        onlyFromOwnerOrNamed("chain_pauser")
    { }
}
