// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { ICrossChainSync } from "../common/ICrossChainSync.sol";
import { Proxied } from "../common/Proxied.sol";

import { LibDepositing } from "./libs/LibDepositing.sol";
import { LibProposing } from "./libs/LibProposing.sol";
import { LibProving } from "./libs/LibProving.sol";
import { LibTiers } from "./libs/LibTiers.sol";
import { LibUtils } from "./libs/LibUtils.sol";
import { LibVerifying } from "./libs/LibVerifying.sol";

import { TaikoData } from "./TaikoData.sol";
import { TaikoErrors } from "./TaikoErrors.sol";
import { TaikoEvents } from "./TaikoEvents.sol";

/// @title TaikoL1
/// @notice This contract serves as the "base layer contract" of the Taiko
/// protocol, providing functionalities for proposing, proving, and verifying
/// blocks. The term "base layer contract" means that although this is usually
/// deployed on L1, it can also be deployed on L2s to create L3s ("inception
/// layers"). The contract also handles the deposit and withdrawal of Taiko
/// tokens and Ether.
contract TaikoL1 is
    EssentialContract,
    ICrossChainSync,
    TaikoEvents,
    TaikoErrors
{
    TaikoData.State public state;
    uint256[100] private __gap;

    /// @dev Fallback function to receive Ether and deposit to to Layer 2.
    receive() external payable {
        depositEtherToL2(address(0));
    }

    /// @notice Initializes the rollup.
    /// @param _addressManager The {AddressManager} address.
    /// @param _genesisBlockHash The block hash of the genesis block.
    function init(
        address _addressManager,
        bytes32 _genesisBlockHash
    )
        external
        initializer
    {
        EssentialContract._init(_addressManager);
        LibVerifying.init({
            state: state,
            config: getConfig(),
            genesisBlockHash: _genesisBlockHash
        });
    }

    /// @notice Proposes a Taiko L2 block.
    /// @param txListHash The hash of the block's txList
    /// @param assignment Data to assign a prover.
    /// @param txList A list of transactions in this block, encoded with RLP.
    /// Note, in the corresponding L2 block an "anchor transaction" will be the
    /// first transaction in the block. If there are `n` transactions in the
    /// `txList`, then there will be up to `n + 1` transactions in the L2 block.
    /// @return meta The metadata of the proposed L2 block.
    function proposeBlock(
        bytes32 txListHash,
        bytes calldata assignment,
        bytes calldata txList
    )
        external
        payable
        nonReentrant
        returns (TaikoData.BlockMetadata memory meta)
    {
        TaikoData.Config memory config = getConfig();
        meta = LibProposing.proposeBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            txListHash: txListHash,
            assignment: abi.decode(assignment, (TaikoData.ProverAssignment)),
            txList: txList
        });
        if (config.blockMaxVerificationsPerTx > 0) {
            LibVerifying.verifyBlocks({
                state: state,
                config: config,
                resolver: AddressResolver(this),
                maxBlocks: config.blockMaxVerificationsPerTx
            });
        }
    }

    /// @notice Proves or contests a block transition.
    /// @param blockId The index of the block to prove. This is also used to
    /// select the right implementation version.
    /// @param input An abi-encoded {TaikoData.BlockEvidence} object.
    function proveBlock(
        uint64 blockId,
        bytes calldata input
    )
        external
        nonReentrant
    {
        TaikoData.Config memory config = getConfig();
        LibProving.proveBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            blockId: blockId,
            evidence: abi.decode(input, (TaikoData.BlockEvidence))
        });
        if (config.blockMaxVerificationsPerTx > 0) {
            LibVerifying.verifyBlocks({
                state: state,
                config: config,
                resolver: AddressResolver(this),
                maxBlocks: config.blockMaxVerificationsPerTx
            });
        }
    }

    /// @notice Verifies up to N blocks.
    /// @param maxBlocks Max number of blocks to verify.
    function verifyBlocks(uint64 maxBlocks) external nonReentrant {
        if (maxBlocks == 0) revert L1_INVALID_PARAM();
        LibVerifying.verifyBlocks({
            state: state,
            config: getConfig(),
            resolver: AddressResolver(this),
            maxBlocks: maxBlocks
        });
    }

    /// @notice Deposits Ether to Layer 2.
    /// @param recipient Address of the recipient for the deposited Ether on
    /// Layer 2.
    function depositEtherToL2(address recipient) public payable {
        LibDepositing.depositEtherToL2({
            state: state,
            config: getConfig(),
            resolver: AddressResolver(this),
            recipient: recipient
        });
    }

    /// @notice Checks if Ether deposit is allowed for Layer 2.
    /// @param amount Amount of Ether to be deposited.
    /// @return true if Ether deposit is allowed, false otherwise.
    function canDepositEthToL2(uint256 amount) public view returns (bool) {
        return LibDepositing.canDepositEthToL2({
            state: state,
            config: getConfig(),
            amount: amount
        });
    }

    /// @notice Gets the details of a block.
    /// @param blockId Index of the block.
    /// @return blk The block.
    function getBlock(uint64 blockId)
        public
        view
        returns (TaikoData.Block memory blk)
    {
        return LibUtils.getBlock({
            state: state,
            config: getConfig(),
            blockId: blockId
        });
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
        returns (TaikoData.Transition memory)
    {
        return LibUtils.getTransition({
            state: state,
            config: getConfig(),
            blockId: blockId,
            parentHash: parentHash
        });
    }

    /// @inheritdoc ICrossChainSync
    function getCrossChainBlockHash(uint64 blockId)
        public
        view
        override
        returns (bytes32)
    {
        return LibUtils.getVerifyingTransition(state, getConfig(), blockId)
            .blockHash;
    }

    /// @inheritdoc ICrossChainSync
    function getCrossChainSignalRoot(uint64 blockId)
        public
        view
        override
        returns (bytes32)
    {
        return LibUtils.getVerifyingTransition(state, getConfig(), blockId)
            .signalRoot;
    }

    /// @notice Gets the state variables of the TaikoL1 contract.
    /// @return StateVariables struct containing state variables.
    function getStateVariables()
        public
        view
        returns (TaikoData.StateVariables memory)
    {
        return LibUtils.getStateVariables(state);
    }

    /// @notice Retrieves the configuration for a specified tier.
    /// @param tierId ID of the tier.
    /// @return TierConfig struct containing the tier's parameters. This
    /// function will revert if the tier is not supported.
    function getTierConfig(uint16 tierId)
        public
        pure
        virtual
        returns (TaikoData.TierConfig memory)
    {
        return LibTiers.getTierConfig(tierId);
    }

    /// @notice Retrieves the IDs of all supported tiers.
    function getTierIds() public pure virtual returns (uint16[] memory) {
        return LibTiers.getTierIds();
    }

    /// @notice Gets the configuration of the TaikoL1 contract.
    /// @return Config struct containing configuration parameters.
    function getConfig()
        public
        pure
        virtual
        returns (TaikoData.Config memory)
    {
        return TaikoData.Config({
            chainId: 167_007,
            relaySignalRoot: false,
            blockMaxProposals: 403_200,
            blockRingBufferSize: 403_210,
            // This number is calculated from blockMaxProposals to make the
            // maximum value of the multiplier close to 20.0
            blockMaxVerificationsPerTx: 10,
            blockMaxGasLimit: 8_000_000,
            blockFeeBaseGas: 20_000,
            blockMaxTxListBytes: 120_000,
            proposerRewardPerSecond: 25e16, // 0.25 Taiko token
            proposerRewardMax: 32e18, // 32 Taiko token
            assignmentBond: 10_240e18,
            ethDepositRingBufferSize: 1024,
            ethDepositMinCountPerBlock: 8,
            ethDepositMaxCountPerBlock: 32,
            ethDepositMinAmount: 1 ether,
            ethDepositMaxAmount: 10_000 ether,
            ethDepositGas: 21_000,
            ethDepositMaxFee: 1 ether / 10
        });
    }
}

/// @title ProxiedTaikoL1
/// @notice Proxied version of the parent contract.
contract ProxiedTaikoL1 is Proxied, TaikoL1 { }
