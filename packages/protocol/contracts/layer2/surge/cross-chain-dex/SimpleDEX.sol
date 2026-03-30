// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title SimpleDEX
/// @notice UniV2-style AMM for single ETH/ERC20 pair with 0.3% fee
/// @dev Implements x*y=k constant product formula
/// @custom:security-contact security@taiko.xyz
contract SimpleDEX {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Fee numerator (3 = 0.3% fee)
    uint256 public constant FEE_NUMERATOR = 3;

    /// @notice Fee denominator
    uint256 public constant FEE_DENOMINATOR = 1000;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The ERC20 token paired with ETH
    IERC20 public immutable token;

    /// @notice Admin/owner who can add initial liquidity
    address public immutable admin;

    /// @notice Authorized liquidity provider (e.g., the L2 vault)
    address public liquidityProvider;

    /// @notice ETH reserve in the pool
    uint256 public reserveETH;

    /// @notice Token reserve in the pool
    uint256 public reserveToken;

    /// @notice Total liquidity shares outstanding
    uint256 public totalShares;

    /// @notice Liquidity shares per provider address
    mapping(address provider => uint256 shares) public liquiditySharesOf;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount, uint256 shares);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount, uint256 tokenAmount, uint256 shares);
    event LiquidityProviderSet(address indexed provider);
    event SwapETHForToken(address indexed user, uint256 ethIn, uint256 tokenOut);
    event SwapTokenForETH(address indexed user, uint256 tokenIn, uint256 ethOut);

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ONLY_ADMIN();
    error INSUFFICIENT_OUTPUT();
    error INSUFFICIENT_LIQUIDITY();
    error ZERO_AMOUNT();
    error NO_LIQUIDITY();
    error ETH_TRANSFER_FAILED();

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(address _token, address _admin) {
        token = IERC20(_token);
        admin = _admin;
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Sets an authorized liquidity provider (e.g., the L2 vault)
    /// @param _provider The address to authorize
    function setLiquidityProvider(address _provider) external {
        if (msg.sender != admin) revert ONLY_ADMIN();
        liquidityProvider = _provider;
        emit LiquidityProviderSet(_provider);
    }

    /// @notice Adds liquidity to the pool and attributes shares to _provider
    /// @param _tokenAmount Amount of tokens to add
    /// @param _provider Address to credit liquidity shares to
    function addLiquidity(uint256 _tokenAmount, address _provider) external payable {
        if (msg.sender != admin && msg.sender != liquidityProvider) revert ONLY_ADMIN();
        if (msg.value == 0 || _tokenAmount == 0) revert ZERO_AMOUNT();

        token.safeTransferFrom(msg.sender, address(this), _tokenAmount);

        uint256 shares;
        if (totalShares == 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * totalShares) / reserveETH;
        }

        liquiditySharesOf[_provider] += shares;
        totalShares += shares;

        reserveETH += msg.value;
        reserveToken += _tokenAmount;

        emit LiquidityAdded(_provider, msg.value, _tokenAmount, shares);
    }

    /// @notice Removes all liquidity for _provider, sends ETH and tokens to msg.sender
    /// @param _provider Address whose liquidity to remove
    /// @return ethAmount_ ETH returned
    /// @return tokenAmount_ Tokens returned
    function removeLiquidity(address _provider)
        external
        returns (uint256 ethAmount_, uint256 tokenAmount_)
    {
        if (msg.sender != admin && msg.sender != liquidityProvider) revert ONLY_ADMIN();

        uint256 shares = liquiditySharesOf[_provider];
        if (shares == 0) revert NO_LIQUIDITY();

        ethAmount_ = (shares * reserveETH) / totalShares;
        tokenAmount_ = (shares * reserveToken) / totalShares;

        liquiditySharesOf[_provider] = 0;
        totalShares -= shares;
        reserveETH -= ethAmount_;
        reserveToken -= tokenAmount_;

        (bool success,) = msg.sender.call{ value: ethAmount_ }("");
        if (!success) revert ETH_TRANSFER_FAILED();
        token.safeTransfer(msg.sender, tokenAmount_);

        emit LiquidityRemoved(_provider, ethAmount_, tokenAmount_, shares);
    }

    /// @notice Returns the current liquidity position for a provider
    /// @param _provider Address to query
    /// @return ethAmount_ ETH value of position
    /// @return tokenAmount_ Token value of position
    function getLiquidity(address _provider)
        external
        view
        returns (uint256 ethAmount_, uint256 tokenAmount_)
    {
        uint256 shares = liquiditySharesOf[_provider];
        if (shares == 0 || totalShares == 0) return (0, 0);
        ethAmount_ = (shares * reserveETH) / totalShares;
        tokenAmount_ = (shares * reserveToken) / totalShares;
    }

    /// @notice Swaps ETH for tokens
    /// @param _minTokenOut Minimum tokens expected (slippage protection)
    /// @return tokenOut_ Actual tokens received
    function swapETHForToken(uint256 _minTokenOut) external payable returns (uint256 tokenOut_) {
        if (msg.value == 0) revert ZERO_AMOUNT();

        tokenOut_ = getAmountOut(msg.value, reserveETH, reserveToken);

        if (tokenOut_ < _minTokenOut) revert INSUFFICIENT_OUTPUT();
        if (tokenOut_ > reserveToken) revert INSUFFICIENT_LIQUIDITY();

        // Update reserves
        reserveETH += msg.value;
        reserveToken -= tokenOut_;

        // Transfer tokens out
        token.safeTransfer(msg.sender, tokenOut_);

        emit SwapETHForToken(msg.sender, msg.value, tokenOut_);
    }

    /// @notice Swaps tokens for ETH
    /// @param _tokenIn Amount of tokens to swap
    /// @param _minETHOut Minimum ETH expected (slippage protection)
    /// @return ethOut_ Actual ETH received
    function swapTokenForETH(uint256 _tokenIn, uint256 _minETHOut) external returns (uint256 ethOut_) {
        if (_tokenIn == 0) revert ZERO_AMOUNT();

        ethOut_ = getAmountOut(_tokenIn, reserveToken, reserveETH);

        if (ethOut_ < _minETHOut) revert INSUFFICIENT_OUTPUT();
        if (ethOut_ > reserveETH) revert INSUFFICIENT_LIQUIDITY();

        // Transfer tokens in first
        token.safeTransferFrom(msg.sender, address(this), _tokenIn);

        // Update reserves
        reserveToken += _tokenIn;
        reserveETH -= ethOut_;

        // Transfer ETH out
        (bool success,) = msg.sender.call{ value: ethOut_ }("");
        if (!success) revert ETH_TRANSFER_FAILED();

        emit SwapTokenForETH(msg.sender, _tokenIn, ethOut_);
    }

    /// @notice Calculates output amount using constant product formula with 0.3% fee
    /// @dev amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
    /// @param _amountIn Input amount
    /// @param _reserveIn Input reserve
    /// @param _reserveOut Output reserve
    /// @return amountOut_ Output amount
    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    )
        public
        pure
        returns (uint256 amountOut_)
    {
        if (_amountIn == 0) revert ZERO_AMOUNT();
        if (_reserveIn == 0 || _reserveOut == 0) revert INSUFFICIENT_LIQUIDITY();

        uint256 amountInWithFee = _amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = (_reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        amountOut_ = numerator / denominator;
    }

    /// @notice Returns current reserves
    /// @return ethReserve_ ETH reserve
    /// @return tokenReserve_ Token reserve
    function getReserves() external view returns (uint256 ethReserve_, uint256 tokenReserve_) {
        return (reserveETH, reserveToken);
    }

    // ---------------------------------------------------------------
    // Receive ETH
    // ---------------------------------------------------------------

    receive() external payable { }
}
