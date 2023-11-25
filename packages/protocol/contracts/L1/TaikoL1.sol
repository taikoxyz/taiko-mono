// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "../common/EssentialContract.sol";
import "./libs/LibDepositing.sol";
import "./libs/LibProposing.sol";
import "./libs/LibProving.sol";
import "./libs/LibVerifying.sol";
import "./TaikoErrors.sol";
import "./TaikoEvents.sol";

/// @title TaikoL1
/// @dev Labeled in AddressResolver as "taiko"
/// @notice This contract serves as the "base layer contract" of the Taiko
/// protocol, providing functionalities for proposing, proving, and verifying
/// blocks. The term "base layer contract" means that although this is usually
/// deployed on L1, it can also be deployed on L2s to create L3s ("inception
/// layers"). The contract also handles the deposit and withdrawal of Taiko
/// tokens and Ether.
/// This contract doesn't hold any Ether. Ether deposited to L2 are held by the Bridge contract.
contract TaikoL1 is EssentialContract, ICrossChainSync, ITierProvider, TaikoEvents, TaikoErrors {
    TaikoData.State public state;
    uint256[100] private __gap;

    /// @dev Fallback function to receive Ether from Hooks
    receive() external payable {
        if (!_inNonReentrant()) revert L1_RECEIVE_DISABLED();
    }

    /// @notice Initializes the rollup.
    /// @param _addressManager The {AddressManager} address.
    /// @param _genesisBlockHash The block hash of the genesis block.
    function init(address _addressManager, bytes32 _genesisBlockHash) external initializer {
        _Essential_init(_addressManager);
        LibVerifying.init(state, getConfig(), _genesisBlockHash);
    }

    /// @notice Proposes a Taiko L2 block.
    /// @param params Block parameters, currently an encoded BlockParams object.
    /// @param txList txList data if calldata is used for DA.
    /// @return meta The metadata of the proposed L2 block.
    /// @return depositsProcessed The Ether deposits processed.
    function proposeBlock(
        bytes calldata params,
        bytes calldata txList
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (
            TaikoData.BlockMetadata memory meta,
            TaikoData.EthDeposit[] memory depositsProcessed
        )
    {
        TaikoData.Config memory config = getConfig();

        (meta, depositsProcessed) =
            LibProposing.proposeBlock(state, config, AddressResolver(this), params, txList);

        if (!state.slotB.provingPaused && config.maxBlocksToVerifyPerProposal > 0) {
            LibVerifying.verifyBlocks(
                state, config, AddressResolver(this), config.maxBlocksToVerifyPerProposal
            );
        }
    }

    /// @notice Proves or contests a block transition.
    /// @param blockId The index of the block to prove. This is also used to
    /// select the right implementation version.
    /// @param input An abi-encoded (BlockMetadata, Transition, TierProof)
    /// tuple.
    function proveBlock(uint64 blockId, bytes calldata input) external nonReentrant whenNotPaused {
        if (state.slotB.provingPaused) revert L1_PROVING_PAUSED();

        (
            TaikoData.BlockMetadata memory meta,
            TaikoData.Transition memory tran,
            TaikoData.TierProof memory proof
        ) = abi.decode(input, (TaikoData.BlockMetadata, TaikoData.Transition, TaikoData.TierProof));

        if (blockId != meta.id) revert L1_INVALID_BLOCK_ID();

        TaikoData.Config memory config = getConfig();

        uint8 maxBlocksToVerify =
            LibProving.proveBlock(state, config, AddressResolver(this), meta, tran, proof);

        if (maxBlocksToVerify > 0) {
            LibVerifying.verifyBlocks(state, config, AddressResolver(this), maxBlocksToVerify);
        }
    }

    /// @notice Verifies up to N blocks.
    /// @param maxBlocksToVerify Max number of blocks to verify.
    function verifyBlocks(uint64 maxBlocksToVerify) external nonReentrant whenNotPaused {
        if (maxBlocksToVerify == 0) revert L1_INVALID_PARAM();
        if (state.slotB.provingPaused) revert L1_PROVING_PAUSED();

        LibVerifying.verifyBlocks(state, getConfig(), AddressResolver(this), maxBlocksToVerify);
    }

    /// @notice Pause block proving.
    /// @param pause True if paused.
    function pauseProving(bool pause) external onlyOwner {
        LibProving.pauseProving(state, pause);
    }

    /// @notice Deposits Ether to Layer 2.
    /// @param recipient Address of the recipient for the deposited Ether on
    /// Layer 2.
    function depositEtherToL2(address recipient) external payable whenNotPaused {
        LibDepositing.depositEtherToL2(state, getConfig(), AddressResolver(this), recipient);
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
    /// @return blk The block.
    function getBlock(uint64 blockId) public view returns (TaikoData.Block memory blk) {
        return LibUtils.getBlock(state, getConfig(), blockId);
    }

    /// @notice Gets the state transition for a specific block.
    /// @param blockId Index of the block.
    /// @param parentHash Parent hash of the block.
    /// @return The state transition data of the block.
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

    /// @inheritdoc ICrossChainSync
    function getSyncedSnippet(uint64 blockId)
        public
        view
        override
        returns (ICrossChainSync.Snippet memory)
    {
        return LibUtils.getSyncedSnippet(state, getConfig(), blockId);
    }

    /// @notice Gets the state variables of the TaikoL1 contract.
    function getStateVariables()
        public
        view
        returns (TaikoData.SlotA memory a, TaikoData.SlotB memory b)
    {
        a = state.slotA;
        b = state.slotB;
    }

    /// @notice Gets the in-protocol Taiko token balance for a user
    /// @param user The user.
    /// @return The user's Taiko token balance.
    function getTaikoTokenBalance(address user) public view returns (uint256) {
        return state.tokenBalances[user];
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

    /// @notice Retrieves the IDs of all supported tiers.
    function getTierIds() public view virtual override returns (uint16[] memory ids) {
        ids = ITierProvider(resolve("tier_provider", false)).getTierIds();
        if (ids.length >= type(uint8).max) revert L1_TOO_MANY_TIERS();
    }

    /// @notice Determines the minimal tier for a block based on a random input.
    function getMinTier(uint256 rand) public view virtual override returns (uint16) {
        return ITierProvider(resolve("tier_provider", false)).getMinTier(rand);
    }

    /// @notice Gets the configuration of the TaikoL1 contract.
    /// @return Config struct containing configuration parameters.
    function getConfig() public view virtual returns (TaikoData.Config memory) {
        // All hard-coded configurations:
        // - treasury: 0xdf09A0afD09a63fb04ab3573922437e1e637dE8b
        // - blockMaxTxs: 150 (limited by the PSE zkEVM circuits)
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
            // Limited by the PSE zkEVM circuits.
            blockMaxGasLimit: 15_000_000,
            // Each go-ethereum transaction has a size limit of 128KB,
            // and right now txList is still saved in calldata, so we set it
            // to 120KB.
            blockMaxTxListBytes: 120_000,
            blobExpiry: 24 hours,
            blobAllowedForDA: false,
            livenessBond: 250e18, // 250 Taiko token
            // ETH deposit related.
            ethDepositRingBufferSize: 1024,
            ethDepositMinCountPerBlock: 8,
            ethDepositMaxCountPerBlock: 32,
            ethDepositMinAmount: 1 ether,
            ethDepositMaxAmount: 10_000 ether,
            ethDepositGas: 21_000,
            ethDepositMaxFee: 1 ether / 10
        });
    }

    function isConfigValid() public view returns (bool) {
        return LibVerifying.isConfigValid(getConfig());
    }
}
