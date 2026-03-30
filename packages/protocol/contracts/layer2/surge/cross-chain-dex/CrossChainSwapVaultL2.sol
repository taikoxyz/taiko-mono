// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IBridge } from "../../../shared/bridge/IBridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ISwapTokenL2 {
    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
}

interface ISimpleDEX {
    function swapETHForToken(uint256 _minTokenOut) external payable returns (uint256);
    function swapTokenForETH(uint256 _tokenIn, uint256 _minETHOut) external returns (uint256);
    function addLiquidity(uint256 _tokenAmount, address _provider) external payable;
    function removeLiquidity(address _provider) external returns (uint256, uint256);
    function token() external view returns (IERC20);
}

/// @title CrossChainSwapVaultL2
/// @notice L2 counterpart of CrossChainSwapVaultL1. Receives bridge messages and
/// handles minting bridged tokens, DEX swaps, and liquidity provisioning.
/// @dev Has minting authority over the bridged ERC20 (SwapTokenL2).
/// @custom:security-contact security@taiko.xyz
contract CrossChainSwapVaultL2 {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Enums (must match L1 vault)
    // ---------------------------------------------------------------

    enum Action {
        BRIDGE,
        SWAP_ETH_TO_TOKEN,
        SWAP_TOKEN_TO_ETH,
        ADD_LIQUIDITY,
        REMOVE_LIQUIDITY
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    address public immutable bridge;
    uint64 public immutable l1ChainId;
    ISimpleDEX public immutable dex;
    ISwapTokenL2 public immutable swapToken;
    IERC20 public immutable swapTokenERC20;
    address public immutable admin;
    address public l1Vault;

    uint32 public constant GAS_LIMIT = 1_000_000;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event L1VaultSet(address indexed l1Vault);
    event TokensBridged(address indexed recipient, uint256 amount);
    event SwapExecutedETHToToken(address indexed recipient, uint256 ethIn, uint256 tokenOut);
    event SwapExecutedTokenToETH(address indexed recipient, uint256 tokenIn, uint256 ethOut);
    event LiquidityAdded(uint256 ethAmount, uint256 tokenAmount);

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ONLY_ADMIN();
    error ONLY_BRIDGE();
    error INVALID_SENDER();
    error L1_VAULT_NOT_SET();
    error UNKNOWN_ACTION();

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(address _bridge, uint64 _l1ChainId, address _dex, address _swapToken, address _admin) {
        bridge = _bridge;
        l1ChainId = _l1ChainId;
        dex = ISimpleDEX(_dex);
        swapToken = ISwapTokenL2(_swapToken);
        swapTokenERC20 = IERC20(_swapToken);
        admin = _admin;
    }

    // ---------------------------------------------------------------
    // Admin
    // ---------------------------------------------------------------

    function setL1Vault(address _l1Vault) external {
        if (msg.sender != admin) revert ONLY_ADMIN();
        l1Vault = _l1Vault;
        emit L1VaultSet(_l1Vault);
    }

    // ---------------------------------------------------------------
    // Bridge Callback (from L1)
    // ---------------------------------------------------------------

    /// @notice Called by bridge when L1 vault sends a message
    function onMessageInvocation(bytes calldata _data) external payable {
        if (msg.sender != bridge) revert ONLY_BRIDGE();

        IBridge.Context memory ctx = IBridge(bridge).context();
        if (l1Vault == address(0)) revert L1_VAULT_NOT_SET();
        if (ctx.from != l1Vault) revert INVALID_SENDER();

        Action action = abi.decode(_data, (Action));

        if (action == Action.BRIDGE) {
            _handleBridge(_data);
        } else if (action == Action.SWAP_ETH_TO_TOKEN) {
            _handleSwapETHToToken(_data);
        } else if (action == Action.SWAP_TOKEN_TO_ETH) {
            _handleSwapTokenToETH(_data);
        } else if (action == Action.ADD_LIQUIDITY) {
            _handleAddLiquidity(_data);
        } else if (action == Action.REMOVE_LIQUIDITY) {
            _handleRemoveLiquidity(_data);
        } else {
            revert UNKNOWN_ACTION();
        }
    }

    // ---------------------------------------------------------------
    // Internal Handlers
    // ---------------------------------------------------------------

    /// @dev Bridge: mint bridged tokens to recipient (1 message, done)
    function _handleBridge(bytes calldata _data) internal {
        (, address recipient, uint256 amount) = abi.decode(_data, (Action, address, uint256));
        swapToken.mint(recipient, amount);
        emit TokensBridged(recipient, amount);
    }

    /// @dev ETH→Token swap: receive ETH, swap on DEX, burn tokens, send completion to L1
    function _handleSwapETHToToken(bytes calldata _data) internal {
        (,, address recipient,, uint256 minTokenOut) =
            abi.decode(_data, (Action, address, address, uint256, uint256));

        // Swap ETH on DEX — DEX sends tokens to this contract
        uint256 tokenOut = dex.swapETHForToken{ value: msg.value }(minTokenOut);

        // Burn the received bridged tokens (they correspond to canonical tokens
        // that will be released from the L1 vault)
        swapToken.burn(address(this), tokenOut);

        emit SwapExecutedETHToToken(recipient, msg.value, tokenOut);

        // Send completion message to L1 vault (no ETH, just "release tokens")
        bytes memory completionData = abi.encode(Action.SWAP_ETH_TO_TOKEN, recipient, tokenOut);
        _sendMessageToL1(completionData, 0);
    }

    /// @dev Token→ETH swap: mint tokens, swap on DEX for ETH, send ETH + completion to L1
    function _handleSwapTokenToETH(bytes calldata _data) internal {
        (,, address recipient, uint256 tokenAmount, uint256 minETHOut) =
            abi.decode(_data, (Action, address, address, uint256, uint256));

        // Mint bridged tokens to this contract (representing locked canonical tokens on L1)
        swapToken.mint(address(this), tokenAmount);

        // Approve DEX and swap tokens for ETH
        swapTokenERC20.approve(address(dex), tokenAmount);
        uint256 ethOut = dex.swapTokenForETH(tokenAmount, minETHOut);

        emit SwapExecutedTokenToETH(recipient, tokenAmount, ethOut);

        // Send completion message with ETH back to L1 vault
        bytes memory completionData = abi.encode(Action.SWAP_TOKEN_TO_ETH, recipient, ethOut);
        _sendMessageToL1(completionData, ethOut);
    }

    /// @dev Add liquidity: mint tokens, add to DEX (1 message, done)
    function _handleAddLiquidity(bytes calldata _data) internal {
        (, address provider, uint256 tokenAmount) = abi.decode(_data, (Action, address, uint256));

        // Mint bridged tokens to this contract
        swapToken.mint(address(this), tokenAmount);

        // Approve DEX and add liquidity
        swapTokenERC20.approve(address(dex), tokenAmount);
        dex.addLiquidity{ value: msg.value }(tokenAmount, provider);

        emit LiquidityAdded(msg.value, tokenAmount);
    }

    /// @dev Remove liquidity: pull from DEX, burn tokens, send ETH + completion to L1
    function _handleRemoveLiquidity(bytes calldata _data) internal {
        (, address provider) = abi.decode(_data, (Action, address));

        (uint256 ethAmount, uint256 tokenAmount) = dex.removeLiquidity(provider);

        // Burn the returned tokens
        if (tokenAmount > 0) {
            swapToken.burn(address(this), tokenAmount);
        }

        // Send completion message with ETH back to L1 vault
        bytes memory completionData = abi.encode(Action.REMOVE_LIQUIDITY, provider, tokenAmount);
        _sendMessageToL1(completionData, ethAmount);
    }

    // ---------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------

    function _sendMessageToL1(bytes memory _innerData, uint256 _ethValue) internal {
        bytes memory msgData = abi.encodeWithSignature("onMessageInvocation(bytes)", _innerData);

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: GAS_LIMIT,
            from: address(0),
            srcChainId: 0,
            srcOwner: address(this),
            destChainId: l1ChainId,
            destOwner: l1Vault,
            to: l1Vault,
            value: _ethValue,
            data: msgData
        });

        IBridge(bridge).sendMessage{ value: _ethValue }(message);
    }

    // ---------------------------------------------------------------
    // Receive ETH
    // ---------------------------------------------------------------

    receive() external payable { }
}
