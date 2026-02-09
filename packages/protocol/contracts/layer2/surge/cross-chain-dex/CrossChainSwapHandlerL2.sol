// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IBridge } from "../../../shared/bridge/IBridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ISimpleDEX {
    function swapETHForToken(uint256 _minTokenOut) external payable returns (uint256);
    function swapTokenForETH(uint256 _tokenIn, uint256 _minETHOut) external returns (uint256);
    function token() external view returns (IERC20);
}

/// @title CrossChainSwapHandlerL2
/// @notice Processes cross-chain swaps on L2 and returns results to L1
/// @custom:security-contact security@taiko.xyz
contract CrossChainSwapHandlerL2 {
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

    /// @notice The L1 chain ID
    uint64 public immutable l1ChainId;

    /// @notice The DEX contract
    ISimpleDEX public immutable dex;

    /// @notice The L2 swap token
    IERC20 public immutable swapTokenL2;

    /// @notice Admin address for configuration
    address public immutable admin;

    /// @notice The L1 handler address (set after L1 deployment)
    address public l1Handler;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event SwapExecutedETHToToken(
        address indexed initiator, address indexed recipient, uint256 ethIn, uint256 tokenOut
    );

    event SwapExecutedTokenToETH(
        address indexed initiator, address indexed recipient, uint256 tokenIn, uint256 ethOut
    );

    event L1HandlerSet(address indexed l1Handler);

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ONLY_ADMIN();
    error ONLY_BRIDGE();
    error INVALID_SENDER();
    error L1_HANDLER_NOT_SET();

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(address _bridge, uint64 _l1ChainId, address _dex, address _admin) {
        bridge = _bridge;
        l1ChainId = _l1ChainId;
        dex = ISimpleDEX(_dex);
        swapTokenL2 = dex.token();
        admin = _admin;
    }

    // ---------------------------------------------------------------
    // Admin Functions
    // ---------------------------------------------------------------

    /// @notice Sets the L1 handler address (called after L1 deployment)
    /// @param _l1Handler The L1 handler contract address
    function setL1Handler(address _l1Handler) external {
        if (msg.sender != admin) revert ONLY_ADMIN();
        l1Handler = _l1Handler;
        emit L1HandlerSet(_l1Handler);
    }

    /// @notice Approves DEX to spend tokens (called once after deployment)
    function approveTokenForDEX() external {
        if (msg.sender != admin) revert ONLY_ADMIN();
        swapTokenL2.approve(address(dex), type(uint256).max);
    }

    // ---------------------------------------------------------------
    // Bridge Callback
    // ---------------------------------------------------------------

    /// @notice Called by bridge when swap request arrives from L1
    /// @param _data Encoded swap request data
    function onMessageInvocation(bytes calldata _data) external payable {
        if (msg.sender != bridge) revert ONLY_BRIDGE();

        // Verify the message is from L1 handler
        IBridge.Context memory ctx = IBridge(bridge).context();
        if (ctx.from != l1Handler) revert INVALID_SENDER();
        if (l1Handler == address(0)) revert L1_HANDLER_NOT_SET();

        // Decode swap request
        (SwapType swapType, address initiator, address recipient, uint256 amount, uint256 minOut) =
            abi.decode(_data, (SwapType, address, address, uint256, uint256));

        if (swapType == SwapType.ETH_TO_TOKEN) {
            _handleETHToTokenSwap(initiator, recipient, amount, minOut);
        } else {
            _handleTokenToETHSwap(initiator, recipient, amount, minOut);
        }
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Handles ETH -> Token swap
    /// @param _initiator Original swap initiator on L1
    /// @param _recipient Recipient for tokens on L1
    /// @param _ethAmount ETH amount received via message.value
    /// @param _minTokenOut Minimum tokens expected
    function _handleETHToTokenSwap(
        address _initiator,
        address _recipient,
        uint256 _ethAmount,
        uint256 _minTokenOut
    )
        internal
    {
        // Execute swap on DEX (ETH was received via message.value)
        uint256 tokenOut = dex.swapETHForToken{ value: msg.value }(_minTokenOut);

        emit SwapExecutedETHToToken(_initiator, _recipient, _ethAmount, tokenOut);

        // Tokens stay in this contract (locked on L2)
        // Send message to L1 to release tokens from reserves to recipient
        bytes memory completionData = abi.encode(SwapType.ETH_TO_TOKEN, _recipient, tokenOut);

        bytes memory msgData = abi.encodeWithSignature("onMessageInvocation(bytes)", completionData);

        // Send completion message to L1 (no ETH value)
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 1_000_000,
            from: address(0),
            srcChainId: 0,
            srcOwner: address(this),
            destChainId: l1ChainId,
            destOwner: l1Handler,
            to: l1Handler,
            value: 0,
            data: msgData
        });

        IBridge(bridge).sendMessage(message);
    }

    /// @dev Handles Token -> ETH swap
    /// @param _initiator Original swap initiator on L1
    /// @param _recipient Recipient for ETH on L1
    /// @param _tokenAmount Token amount (locked on L1, virtual here)
    /// @param _minETHOut Minimum ETH expected
    function _handleTokenToETHSwap(
        address _initiator,
        address _recipient,
        uint256 _tokenAmount,
        uint256 _minETHOut
    )
        internal
    {
        // Execute swap on DEX using pre-approved tokens held by this handler
        // These tokens represent the "virtual" bridged tokens matching L1 locked tokens
        uint256 ethOut = dex.swapTokenForETH(_tokenAmount, _minETHOut);

        emit SwapExecutedTokenToETH(_initiator, _recipient, _tokenAmount, ethOut);

        // Send ETH back to L1 recipient via bridge message
        bytes memory completionData = abi.encode(SwapType.TOKEN_TO_ETH, _recipient, ethOut);

        bytes memory msgData = abi.encodeWithSignature("onMessageInvocation(bytes)", completionData);

        // Send completion message with ETH value
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 1_000_000,
            from: address(0),
            srcChainId: 0,
            srcOwner: address(this),
            destChainId: l1ChainId,
            destOwner: l1Handler,
            to: l1Handler,
            value: ethOut,
            data: msgData
        });

        IBridge(bridge).sendMessage{ value: ethOut }(message);
    }

    // ---------------------------------------------------------------
    // Receive ETH
    // ---------------------------------------------------------------

    receive() external payable { }
}
