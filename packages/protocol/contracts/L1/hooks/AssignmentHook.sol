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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../common/EssentialContract.sol";
import "../../libs/LibAddress.sol";
import "../ITaikoL1.sol";
import "./IHook.sol";

/// @title AssignmentHook
/// A hook that handles prover assignment varification and fee processing.
contract AssignmentHook is EssentialContract, IHook {
    using LibAddress for address;
    using SafeERC20 for IERC20;

    struct ProverAssignment {
        address feeToken;
        uint64 expiry;
        uint64 maxBlockId;
        uint64 maxProposedIn;
        bytes32 metaHash;
        bytes32 parentMetaHash;
        TaikoData.TierFee[] tierFees;
        bytes signature;
    }

    struct Input {
        ProverAssignment assignment;
        uint256 tip; // A tip to L1 block builder
    }

    // Max gas paying the prover. This should be large enough to prevent the
    // worst cases for the prover. To assure a trustless relationship between
    // the proposer and the prover it's the prover's job to make sure it can
    // get paid within this limit.
    uint256 public constant MAX_GAS_PAYING_PROVER = 50_000;

    uint256[50] private __gap;

    event BlockAssigned(
        address indexed assignedProver, TaikoData.BlockMetadata meta, ProverAssignment assignment
    );

    error HOOK_ASSIGNMENT_EXPIRED();
    error HOOK_ASSIGNMENT_INVALID_SIG();
    error HOOK_ASSIGNMENT_INSUFFICIENT_FEE();
    error HOOK_TIER_NOT_FOUND();

    function init(address _owner, address _addressManager) external initializer initEssential(_owner, _addressManager){
    }

    function onBlockProposed(
        TaikoData.Block memory blk,
        TaikoData.BlockMetadata memory meta,
        bytes memory data
    )
        external
        payable
        nonReentrant
        onlyFromNamed("taiko")
    {
        // Note that
        // - 'msg.sender' is the TaikoL1 contract address
        // - 'block.coinbase' is the L1 block builder
        // - 'meta.coinbase' is the L2 block proposer

        Input memory input = abi.decode(data, (Input));
        ProverAssignment memory assignment = input.assignment;

        // Check assignment validity
        if (
            block.timestamp > assignment.expiry
                || assignment.metaHash != 0 && blk.metaHash != assignment.metaHash
                || assignment.parentMetaHash != 0 && meta.parentMetaHash != assignment.parentMetaHash
                || assignment.maxBlockId != 0 && meta.id > assignment.maxBlockId
                || assignment.maxProposedIn != 0 && block.number > assignment.maxProposedIn
        ) {
            revert HOOK_ASSIGNMENT_EXPIRED();
        }

        // Hash the assignment with the blobHash, this hash will be signed by
        // the prover, therefore, we add a string as a prefix.
        address taikoL1Address = msg.sender;
        bytes32 hash = hashAssignment(assignment, taikoL1Address, meta.blobHash);

        if (!blk.assignedProver.isValidSignature(hash, assignment.signature)) {
            revert HOOK_ASSIGNMENT_INVALID_SIG();
        }

        // Send the liveness bond to the Taiko contract
        IERC20 tko = IERC20(resolve("taiko_token", false));
        tko.transferFrom(blk.assignedProver, taikoL1Address, blk.livenessBond);

        // Find the prover fee using the minimal tier
        uint256 proverFee = _getProverFee(assignment.tierFees, meta.minTier);

        // The proposer irrevocably pays a fee to the assigned prover, either in
        // Ether or ERC20 tokens.
        if (assignment.feeToken == address(0)) {
            // Paying Ether
            blk.assignedProver.sendEther(proverFee, MAX_GAS_PAYING_PROVER);
        } else {
            // Paying ERC20 tokens
            IERC20(assignment.feeToken).safeTransferFrom(
                meta.coinbase, blk.assignedProver, proverFee
            );
        }

        // block.coinbase can be address(0) in tests
        if (input.tip != 0 && block.coinbase != address(0)) {
            address(block.coinbase).sendEther(input.tip);
        }

        // Send all remaining Ether back to TaikoL1 contract
        if (address(this).balance > 0) {
            taikoL1Address.sendEther(address(this).balance);
        }

        emit BlockAssigned(blk.assignedProver, meta, assignment);
    }

    function hashAssignment(
        ProverAssignment memory assignment,
        address taikoL1Address,
        bytes32 blobHash
    )
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                "PROVER_ASSIGNMENT",
                ITaikoL1(taikoL1Address).getConfig().chainId,
                taikoL1Address,
                address(this),
                assignment.metaHash,
                assignment.parentMetaHash,
                blobHash,
                assignment.feeToken,
                assignment.expiry,
                assignment.maxBlockId,
                assignment.maxProposedIn,
                assignment.tierFees
            )
        );
    }

    function _getProverFee(
        TaikoData.TierFee[] memory tierFees,
        uint16 tierId
    )
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < tierFees.length; ++i) {
            if (tierFees[i].tier == tierId) return tierFees[i].fee;
        }
        revert HOOK_TIER_NOT_FOUND();
    }
}
