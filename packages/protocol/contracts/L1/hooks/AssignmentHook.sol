// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "../../common/EssentialContract.sol";
import "../../common/LibStrings.sol";
import "../../libs/LibAddress.sol";
import "../ITaikoL1.sol";
import "./IHook.sol";

/// @title AssignmentHook
/// @notice A hook that handles prover assignment verification and fee processing.
/// @custom:security-contact security@taiko.xyz
contract AssignmentHook is EssentialContract, IHook {
    using LibAddress for address;
    using SignatureChecker for address;
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

    event EtherPaymentFailed(address to, uint256 maxGas);

    /// @notice Max gas paying the prover.
    /// @dev This should be large enough to prevent the worst cases for the prover.
    /// To assure a trustless relationship between the proposer and the prover it's
    /// the prover's job to make sure it can get paid within this limit.
    uint256 public constant MAX_GAS_PAYING_PROVER = 50_000;

    uint256[50] private __gap;

    /// @notice Emitted when a block is assigned to a prover.
    /// @param assignedProver The address of the assigned prover.
    /// @param meta The metadata of the assigned block.
    /// @param assignment The prover assignment.
    event BlockAssigned(
        address indexed assignedProver, TaikoData.BlockMetadata meta, ProverAssignment assignment
    );

    error HOOK_ASSIGNMENT_EXPIRED();
    error HOOK_ASSIGNMENT_INVALID_SIG();
    error HOOK_TIER_NOT_FOUND();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
    }

    /// @inheritdoc IHook
    function onBlockProposed(
        TaikoData.Block calldata _blk,
        TaikoData.BlockMetadata calldata _meta,
        bytes calldata _data
    )
        external
        payable
        onlyFromNamed(LibStrings.B_TAIKO)
        nonReentrant
    {
        // Note that
        // - 'msg.sender' is the TaikoL1 contract address
        // - 'block.coinbase' is the L1 block builder
        // - 'meta.coinbase' is the L2 block proposer (chosen by block's proposer)

        Input memory input = abi.decode(_data, (Input));
        ProverAssignment memory assignment = input.assignment;

        // Check assignment validity
        if (
            block.timestamp > assignment.expiry
                || assignment.metaHash != 0 && _blk.metaHash != assignment.metaHash
                || assignment.parentMetaHash != 0 && _meta.parentMetaHash != assignment.parentMetaHash
                || assignment.maxBlockId != 0 && _meta.id > assignment.maxBlockId
                || assignment.maxProposedIn != 0 && block.number > assignment.maxProposedIn
        ) {
            revert HOOK_ASSIGNMENT_EXPIRED();
        }

        // Hash the assignment with the blobHash, this hash will be signed by
        // the prover, therefore, we add a string as a prefix.

        // msg.sender is taikoL1Address
        bytes32 hash = hashAssignment(
            assignment, msg.sender, _meta.sender, _blk.assignedProver, _meta.blobHash
        );

        if (!_blk.assignedProver.isValidSignatureNow(hash, assignment.signature)) {
            revert HOOK_ASSIGNMENT_INVALID_SIG();
        }

        // Send the liveness bond to the Taiko contract
        IERC20 tko = IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false));

        // Note that we don't have to worry about
        // https://github.com/crytic/slither/wiki/Detector-Documentation#arbitrary-from-in-transferfrom
        // as `assignedProver` has provided a signature above to authorize this hook.
        tko.safeTransferFrom(_blk.assignedProver, msg.sender, _blk.livenessBond);

        // Find the prover fee using the minimal tier
        uint256 proverFee = _getProverFee(assignment.tierFees, _meta.minTier);

        // The proposer irrevocably pays a fee to the assigned prover, either in
        // Ether or ERC20 tokens.
        if (assignment.feeToken == address(0)) {
            // Paying Ether even when proverFee is 0 to trigger a potential receive() function call.
            // Note that this payment may fail if it cost more gas
            bool success = _blk.assignedProver.sendEther(proverFee, MAX_GAS_PAYING_PROVER, "");
            if (!success) emit EtherPaymentFailed(_blk.assignedProver, MAX_GAS_PAYING_PROVER);
        } else if (proverFee != 0 && _meta.sender != _blk.assignedProver) {
            // Paying ERC20 tokens
            IERC20(assignment.feeToken).safeTransferFrom(
                _meta.sender, _blk.assignedProver, proverFee
            );
        }

        // block.coinbase can be address(0) in tests
        if (input.tip != 0 && block.coinbase != address(0)) {
            address(block.coinbase).sendEtherAndVerify(input.tip);
        }

        // Send all remaining Ether back to TaikoL1 contract
        if (address(this).balance != 0) {
            msg.sender.sendEtherAndVerify(address(this).balance);
        }

        emit BlockAssigned(_blk.assignedProver, _meta, assignment);
    }

    /// @notice Hashes the prover assignment.
    /// @param _assignment The prover assignment.
    /// @param _taikoL1Address The address of the TaikoL1 contract.
    /// @param _blockProposer The block proposer address.
    /// @param _assignedProver The assigned prover address.
    /// @param _blobHash The blob hash.
    /// @return The hash of the prover assignment.
    function hashAssignment(
        ProverAssignment memory _assignment,
        address _taikoL1Address,
        address _blockProposer,
        address _assignedProver,
        bytes32 _blobHash
    )
        public
        view
        returns (bytes32)
    {
        // split up into two parts otherwise stack is too deep
        bytes32 hash = keccak256(
            abi.encode(
                _assignment.metaHash,
                _assignment.parentMetaHash,
                _assignment.feeToken,
                _assignment.expiry,
                _assignment.maxBlockId,
                _assignment.maxProposedIn,
                _assignment.tierFees
            )
        );

        return keccak256(
            abi.encodePacked(
                LibStrings.B_PROVER_ASSIGNMENT,
                ITaikoL1(_taikoL1Address).getConfig().chainId,
                _taikoL1Address,
                _blockProposer,
                _assignedProver,
                _blobHash,
                hash,
                address(this)
            )
        );
    }

    function _getProverFee(
        TaikoData.TierFee[] memory _tierFees,
        uint16 _tierId
    )
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < _tierFees.length; ++i) {
            if (_tierFees[i].tier == _tierId) return _tierFees[i].fee;
        }
        revert HOOK_TIER_NOT_FOUND();
    }
}
