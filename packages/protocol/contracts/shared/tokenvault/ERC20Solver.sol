// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libs/LibStrings.sol";
import "../../layer1/based/ITaikoInbox.sol";
import "../common/EssentialContract.sol";

/// @title ERC20Solver
/// @notice This enables bridging intent solving feature in erc20vault and facilitates
/// fast withdrawals of tokens when bridging from l2 to l1.
/// @custom:security-contact security@taiko.xyz
contract ERC20Solver is EssentialContract {
    /// @dev Represents an operation to solve an ERC20 bridging intent on destination chain
    struct SolveOp {
        // Nonce for the solver condition
        uint256 nonce;
        // ERC20 token address on destination chain
        address token;
        // Recipient of the tokens
        address to;
        // Amount of tokens to be transferred to the recipient
        uint256 amount;
        // Fields below are used to constrain a solve operation to only pass if an L2 batch
        // containing the initial "intent" transaction is included.
        uint256 l2BlockId;
        bytes32 l2BlockMetaHash;
    }

    error L2_METADATA_HASH_MISMATCH();

    /// @notice Emitted when a bridging intent is solved
    /// @param solverCondition The solver condition hash
    /// @param solver The address of the solver
    event ERC20Solved(bytes32 indexed solverCondition, address solver);

    /// @notice Mapping from solver condition to the address of solver
    mapping(bytes32 solverCondition => address solver) public solverConditionToSolver;

    /// @notice Lets a solver fulfil a bridging intent by transfering the bridged token amount
    // to the recipient.
    /// @param _op Parameters for the solve operation
    function solve(SolveOp memory _op) external nonReentrant whenNotPaused {
        // Verify that the required L2 batch containing the intent transaction has been proposed
        bytes32 _l2BlockMetaHash = (
            ITaikoInbox(resolve(LibStrings.B_TAIKO, false)).getBlockV3(uint64(_op.l2BlockId))
        ).metaHash;
        require(_l2BlockMetaHash == _op.l2BlockMetaHash, L2_METADATA_HASH_MISMATCH());

        // Record the solver's address
        bytes32 _solverCondition = getSolverCondition(_op.nonce, _op.token, _op.to, _op.amount);
        solverConditionToSolver[_solverCondition] = msg.sender;

        // Transfer the amount to the recipient
        IERC20(_op.token).transferFrom(msg.sender, _op.to, _op.amount);

        emit ERC20Solved(_solverCondition, msg.sender);
    }

    /// @notice Returns the solver condition for a bridging intent
    /// @param _nonce Unique numeric value to prevent nonce collision
    /// @param _token Address of the ERC20 token on destination chain
    /// @param _amount Amount of tokens expected by the recipient
    /// @param _to Recipient on destination chain
    /// @return solver condition
    function getSolverCondition(
        uint256 _nonce,
        address _token,
        address _to,
        uint256 _amount
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_nonce, _token, _to, _amount));
    }
}
