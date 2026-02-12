// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IBridge } from "../../../shared/bridge/IBridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title CrossChainSwapVaultL1
/// @notice Unified vault on L1 that handles token bridging, cross-chain swaps,
/// and L2 liquidity provisioning — all in a single message per hop.
/// @dev Holds canonical ERC20 tokens. Implements IMessageInvocable pattern.
/// @custom:security-contact security@taiko.xyz
contract CrossChainSwapVaultL1 {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Enums
    // ---------------------------------------------------------------

    enum Action {
        BRIDGE,
        SWAP_ETH_TO_TOKEN,
        SWAP_TOKEN_TO_ETH,
        ADD_LIQUIDITY
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    address public immutable bridge;
    uint64 public immutable l2ChainId;
    IERC20 public immutable swapToken;
    address public immutable admin;
    address public l2Vault;

    uint32 public constant GAS_LIMIT = 1_000_000;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event L2VaultSet(address indexed l2Vault);
    event TokensBridgedToL2(address indexed from, address indexed recipient, uint256 amount, bytes32 msgHash);
    event SwapETHForTokenInitiated(address indexed user, uint256 ethAmount, uint256 minTokenOut, bytes32 msgHash);
    event SwapTokenForETHInitiated(address indexed user, uint256 tokenAmount, uint256 minETHOut, bytes32 msgHash);
    event LiquidityAddedToL2(address indexed user, uint256 ethAmount, uint256 tokenAmount, bytes32 msgHash);
    event SwapETHForTokenCompleted(address indexed recipient, uint256 tokenAmount);
    event SwapTokenForETHCompleted(address indexed recipient, uint256 ethAmount);

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ONLY_ADMIN();
    error ONLY_BRIDGE();
    error INVALID_SENDER();
    error L2_VAULT_NOT_SET();
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
    // Admin
    // ---------------------------------------------------------------

    function setL2Vault(address _l2Vault) external {
        if (msg.sender != admin) revert ONLY_ADMIN();
        l2Vault = _l2Vault;
        emit L2VaultSet(_l2Vault);
    }

    // ---------------------------------------------------------------
    // Bridge: L1 → L2 (1 message)
    // ---------------------------------------------------------------

    /// @notice Bridge canonical tokens from L1 to L2 (mints bridged tokens on L2)
    /// @param _amount Amount of canonical tokens to bridge
    /// @param _recipient Recipient address on L2
    function bridgeTokenToL2(uint256 _amount, address _recipient) external {
        if (l2Vault == address(0)) revert L2_VAULT_NOT_SET();
        if (_amount == 0) revert ZERO_AMOUNT();

        // Lock canonical tokens in this vault
        swapToken.safeTransferFrom(msg.sender, address(this), _amount);

        bytes memory data = abi.encode(Action.BRIDGE, _recipient, _amount);
        bytes32 msgHash = _sendMessageToL2(data, 0);

        emit TokensBridgedToL2(msg.sender, _recipient, _amount, msgHash);
    }

    // ---------------------------------------------------------------
    // Swap: ETH → Token (2 messages total)
    // ---------------------------------------------------------------

    /// @notice Swap ETH on L1 for tokens. ETH goes to L2 DEX, tokens released from vault.
    /// @param _minTokenOut Minimum tokens expected (slippage protection)
    /// @param _recipient Recipient for tokens on L1
    function swapETHForToken(uint256 _minTokenOut, address _recipient) external payable {
        if (l2Vault == address(0)) revert L2_VAULT_NOT_SET();
        if (msg.value == 0) revert ZERO_AMOUNT();

        bytes memory data = abi.encode(
            Action.SWAP_ETH_TO_TOKEN,
            msg.sender,
            _recipient,
            msg.value,
            _minTokenOut
        );
        bytes32 msgHash = _sendMessageToL2(data, msg.value);

        emit SwapETHForTokenInitiated(msg.sender, msg.value, _minTokenOut, msgHash);
    }

    // ---------------------------------------------------------------
    // Swap: Token → ETH (2 messages total)
    // ---------------------------------------------------------------

    /// @notice Swap tokens on L1 for ETH. Tokens locked, L2 mints + swaps on DEX, ETH bridged back.
    /// @param _tokenAmount Amount of tokens to swap
    /// @param _minETHOut Minimum ETH expected (slippage protection)
    /// @param _recipient Recipient for ETH on L1
    function swapTokenForETH(uint256 _tokenAmount, uint256 _minETHOut, address _recipient) external {
        if (l2Vault == address(0)) revert L2_VAULT_NOT_SET();
        if (_tokenAmount == 0) revert ZERO_AMOUNT();

        // Lock canonical tokens
        swapToken.safeTransferFrom(msg.sender, address(this), _tokenAmount);

        bytes memory data = abi.encode(
            Action.SWAP_TOKEN_TO_ETH,
            msg.sender,
            _recipient,
            _tokenAmount,
            _minETHOut
        );
        bytes32 msgHash = _sendMessageToL2(data, 0);

        emit SwapTokenForETHInitiated(msg.sender, _tokenAmount, _minETHOut, msgHash);
    }

    // ---------------------------------------------------------------
    // Add Liquidity to L2 DEX from L1 (1 message)
    // ---------------------------------------------------------------

    /// @notice Add liquidity to the L2 DEX from L1. Locks tokens + sends ETH.
    /// @param _tokenAmount Amount of canonical tokens to add as liquidity
    function addLiquidityToL2(uint256 _tokenAmount) external payable {
        if (l2Vault == address(0)) revert L2_VAULT_NOT_SET();
        if (msg.value == 0 || _tokenAmount == 0) revert ZERO_AMOUNT();

        // Lock canonical tokens
        swapToken.safeTransferFrom(msg.sender, address(this), _tokenAmount);

        bytes memory data = abi.encode(Action.ADD_LIQUIDITY, _tokenAmount);
        bytes32 msgHash = _sendMessageToL2(data, msg.value);

        emit LiquidityAddedToL2(msg.sender, msg.value, _tokenAmount, msgHash);
    }

    // ---------------------------------------------------------------
    // Bridge Callback (from L2)
    // ---------------------------------------------------------------

    /// @notice Called by bridge when L2 vault sends a completion/bridge message
    function onMessageInvocation(bytes calldata _data) external payable {
        if (msg.sender != bridge) revert ONLY_BRIDGE();

        IBridge.Context memory ctx = IBridge(bridge).context();
        if (ctx.from != l2Vault) revert INVALID_SENDER();

        Action action = abi.decode(_data, (Action));

        if (action == Action.SWAP_ETH_TO_TOKEN) {
            // Completion: L2 swapped ETH for tokens, release canonical tokens to recipient
            (, address recipient, uint256 tokenAmount) = abi.decode(_data, (Action, address, uint256));
            if (swapToken.balanceOf(address(this)) < tokenAmount) revert INSUFFICIENT_TOKEN_BALANCE();
            swapToken.safeTransfer(recipient, tokenAmount);
            emit SwapETHForTokenCompleted(recipient, tokenAmount);
        } else if (action == Action.SWAP_TOKEN_TO_ETH) {
            // Completion: L2 swapped tokens for ETH, forward ETH to recipient
            (, address recipient,) = abi.decode(_data, (Action, address, uint256));
            if (msg.value > 0) {
                (bool success,) = recipient.call{ value: msg.value }("");
                if (!success) revert ETH_TRANSFER_FAILED();
            }
            emit SwapTokenForETHCompleted(recipient, msg.value);
        }
        // BRIDGE and ADD_LIQUIDITY don't have L2→L1 completions
    }

    // ---------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------

    function _sendMessageToL2(bytes memory _innerData, uint256 _ethValue) internal returns (bytes32) {
        bytes memory msgData = abi.encodeWithSignature("onMessageInvocation(bytes)", _innerData);

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: GAS_LIMIT,
            from: address(0),
            srcChainId: 0,
            srcOwner: msg.sender,
            destChainId: l2ChainId,
            destOwner: l2Vault,
            to: l2Vault,
            value: _ethValue,
            data: msgData
        });

        (bytes32 msgHash,) = IBridge(bridge).sendMessage{ value: _ethValue }(message);
        return msgHash;
    }

    // ---------------------------------------------------------------
    // Receive ETH
    // ---------------------------------------------------------------

    receive() external payable { }
}
