// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

// Library Imports
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Local imports
import { L1Executor } from "./L1Executor.sol";
import { BridgingManager } from "./BridgingManager.sol";
import { BridgeableTokens } from "./BridgeableTokens.sol";
import { IL1TokenBridge } from "./interfaces/IL1TokenBridge.sol";
import { IL2TokenBridge } from "./interfaces/IL2TokenBridge.sol";

/// @notice The L1 Standard bridge locks bridged tokens on the L1 side, sends deposit messages
///     on the L2 side, and finalizes token withdrawals from L2.
contract L1TokenBridge is IL1TokenBridge, BridgeableTokens, BridgingManager, L1Executor {
    using SafeERC20 for IERC20;

    address public immutable l2TokenBridge;

    constructor(
        address l1Token_,
        address l2Token_,
        address messenger_, // L1 messenger address being used for cross-chain communications
        address l2TokenBridge_
    )
        BridgeableTokens(l1Token_, l2Token_)
        L1Executor(messenger_)
    {
        l2TokenBridge = l2TokenBridge_;
    }

    function depositTo(
        address l1Token_,
        address to_,
        uint256 amount_,
        uint32 l2Gas_,
        bytes calldata data_
    )
        public
        whenDepositsEnabled
        onlySupportedL1Token(l1Token_)
        onlyNonZeroAccount(to_)
    {
        _initiateTokenDeposit(msg.sender, to_, amount_, l2Gas_, data_);
    }

    function deposit(
        address l1Token_,
        uint256 amount_,
        uint32 l2Gas_,
        bytes calldata data_
    )
        external
    {
        depositTo(l1Token_, msg.sender, amount_, l2Gas_, data_);
    }

    function finalizeWithdrawal(
        address l1Token_,
        address l2Token_,
        address from_,
        address to_,
        uint256 amount_,
        bytes calldata data_
    )
        external
        whenWithdrawalsEnabled
        onlyFromCrossDomainAccount
        onlySupportedL1Token(l1Token_)
        onlySupportedL2Token(l2Token_)
    {
        uint256 before_balance = IERC20(l1Token).balanceOf(address(this));
        IERC20(l1Token).safeTransfer(to_, amount_); // Transfer to User
        uint256 after_balance = IERC20(l1Token).balanceOf(address(this));

        // To handle Fee-on-Transafer and other misc tokens
        require(after_balance - before_balance == amount_, "Incorrect Funds Transferred");

        emit TokenWithdrawalFinalized(l1Token_, l2Token_, from_, to_, amount_, data_);
    }

    function _initiateTokenDeposit(
        address from_,
        address to_,
        uint256 amount_,
        uint32 l2Gas_,
        bytes calldata data_
    )
        internal
    {
        uint256 before_balance = IERC20(l1Token).balanceOf(address(this));
        IERC20(l1Token).safeTransferFrom(from_, address(this), amount_); // Transfer From user.
        uint256 after_balance = IERC20(l1Token).balanceOf(address(this));

        // To handle Fee-on-Transafer and other misc tokens
        require(after_balance - before_balance == amount_, "Incorrect Funds Transferred");

        bytes memory message = abi.encodeWithSelector(
            IL2TokenBridge.finalizeDeposit.selector, l1Token, l2Token, from_, to_, amount_, data_
        );
        // Sends Cross Domain Message
        sendMessage(l2TokenBridge, l2Gas_, message);

        emit TokenDepositInitiated(l1Token, l2Token, from_, to_, amount_, data_);
    }
}
