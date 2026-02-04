// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IBridge } from "../../../shared/bridge/IBridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title CrossChainSwapHandlerL1
/// @notice Handles cross-chain swap requests on L1 for the cross-chain DEX POC
/// @dev Implements IMessageInvocable for receiving bridge messages
/// @custom:security-contact security@taiko.xyz
contract CrossChainSwapHandlerL1 {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Enums
    // ---------------------------------------------------------------

    enum SwapType {
        ETH_TO_TOKEN,
        TOKEN_TO_ETH
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The bridge contract address
    address public immutable bridge;

    /// @notice The L2 chain ID
    uint64 public immutable l2ChainId;

    /// @notice The swap token on L1
    IERC20 public immutable swapToken;

    /// @notice Admin address for configuration
    address public immutable admin;

    /// @notice The L2 handler address (set after L2 deployment)
    address public l2Handler;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event SwapETHForTokenInitiated(
        address indexed user, uint256 ethAmount, uint256 minTokenOut, bytes32 msgHash
    );

    event SwapTokenForETHInitiated(
        address indexed user, uint256 tokenAmount, uint256 minETHOut, bytes32 msgHash
    );

    event SwapETHForTokenCompleted(address indexed user, uint256 tokenAmount);

    event SwapTokenForETHCompleted(address indexed user, uint256 ethAmount);

    event L2HandlerSet(address indexed l2Handler);

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ONLY_ADMIN();
    error ONLY_BRIDGE();
    error INVALID_SENDER();
    error L2_HANDLER_NOT_SET();
    error ZERO_AMOUNT();
    error INSUFFICIENT_TOKEN_BALANCE();
    error ETH_TRANSFER_FAILED();

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(address _bridge, uint64 _l2ChainId, address _swapToken, address _admin) {
        bridge = _bridge;
        l2ChainId = _l2ChainId;
        swapToken = IERC20(_swapToken);
        admin = _admin;
    }

    // ---------------------------------------------------------------
    // Admin Functions
    // ---------------------------------------------------------------

    /// @notice Sets the L2 handler address (called after L2 deployment)
    /// @param _l2Handler The L2 handler contract address
    function setL2Handler(address _l2Handler) external {
        if (msg.sender != admin) revert ONLY_ADMIN();
        l2Handler = _l2Handler;
        emit L2HandlerSet(_l2Handler);
    }

    // ---------------------------------------------------------------
    // Swap Functions (called by UserOpsSubmitter)
    // ---------------------------------------------------------------

    /// @notice Initiates ETH -> ERC20 swap
    /// @dev User sends ETH, which is forwarded to L2 for swapping
    /// @param _minTokenOut Minimum tokens expected (slippage protection)
    /// @param _recipient The recipient on L1 (user's UserOpsSubmitter)
    function swapETHForERC20(uint256 _minTokenOut, address _recipient) external payable {
        if (l2Handler == address(0)) revert L2_HANDLER_NOT_SET();
        if (msg.value == 0) revert ZERO_AMOUNT();

        // Encode swap data for L2
        bytes memory swapData = abi.encode(
            SwapType.ETH_TO_TOKEN,
            msg.sender, // original initiator (UserOpsSubmitter)
            _recipient, // recipient for output
            msg.value, // ETH amount
            _minTokenOut // slippage protection
        );

        bytes memory msgData = abi.encodeWithSignature("onMessageInvocation(bytes)", swapData);

        // Create bridge message with ETH value
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 1_000_000,
            from: address(0),
            srcChainId: 0,
            srcOwner: msg.sender,
            destChainId: l2ChainId,
            destOwner: l2Handler,
            to: l2Handler,
            value: msg.value,
            data: msgData
        });

        // Send message through bridge
        (bytes32 msgHash,) = IBridge(bridge).sendMessage{ value: msg.value }(message);

        emit SwapETHForTokenInitiated(msg.sender, msg.value, _minTokenOut, msgHash);
    }

    /// @notice Initiates ERC20 -> ETH swap
    /// @dev User's ERC20 is locked on L1, message sent to L2 to swap virtual ERC20 for ETH
    /// @param _tokenAmount Amount of tokens to swap
    /// @param _minETHOut Minimum ETH expected (slippage protection)
    /// @param _recipient The recipient on L1 (user's UserOpsSubmitter)
    function swapERC20ForETH(uint256 _tokenAmount, uint256 _minETHOut, address _recipient) external {
        if (l2Handler == address(0)) revert L2_HANDLER_NOT_SET();
        if (_tokenAmount == 0) revert ZERO_AMOUNT();

        // Transfer tokens from user to this contract (lock)
        swapToken.safeTransferFrom(msg.sender, address(this), _tokenAmount);

        // Encode swap data for L2
        bytes memory swapData = abi.encode(
            SwapType.TOKEN_TO_ETH,
            msg.sender, // original initiator (UserOpsSubmitter)
            _recipient, // recipient for output ETH
            _tokenAmount, // token amount
            _minETHOut // slippage protection
        );

        bytes memory msgData = abi.encodeWithSignature("onMessageInvocation(bytes)", swapData);

        // Create bridge message without ETH value
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 1_000_000,
            from: address(0),
            srcChainId: 0,
            srcOwner: msg.sender,
            destChainId: l2ChainId,
            destOwner: l2Handler,
            to: l2Handler,
            value: 0,
            data: msgData
        });

        // Send message through bridge
        (bytes32 msgHash,) = IBridge(bridge).sendMessage(message);

        emit SwapTokenForETHInitiated(msg.sender, _tokenAmount, _minETHOut, msgHash);
    }

    // ---------------------------------------------------------------
    // Bridge Callback
    // ---------------------------------------------------------------

    /// @notice Called by bridge when L2 sends swap completion
    /// @param _data Encoded swap completion data
    function onMessageInvocation(bytes calldata _data) external payable {
        if (msg.sender != bridge) revert ONLY_BRIDGE();

        // Verify the message is from L2 handler
        IBridge.Context memory ctx = IBridge(bridge).context();
        if (ctx.from != l2Handler) revert INVALID_SENDER();

        // Decode completion data
        (SwapType swapType, address recipient, uint256 amount) =
            abi.decode(_data, (SwapType, address, uint256));

        if (swapType == SwapType.ETH_TO_TOKEN) {
            // ETH -> Token swap completed on L2
            // Transfer tokens from reserves to recipient
            if (swapToken.balanceOf(address(this)) < amount) {
                revert INSUFFICIENT_TOKEN_BALANCE();
            }
            swapToken.safeTransfer(recipient, amount);
            emit SwapETHForTokenCompleted(recipient, amount);
        } else if (swapType == SwapType.TOKEN_TO_ETH) {
            // Token -> ETH swap completed on L2
            // ETH was sent via message.value, forward to recipient
            if (msg.value > 0) {
                (bool success,) = recipient.call{ value: msg.value }("");
                if (!success) revert ETH_TRANSFER_FAILED();
            }
            emit SwapTokenForETHCompleted(recipient, msg.value);
        }
    }

    // ---------------------------------------------------------------
    // Receive ETH
    // ---------------------------------------------------------------

    receive() external payable { }
}
