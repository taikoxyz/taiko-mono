// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.24;

import {IBridge} from "../../bridge/IBridge.sol";

/// @notice The L2 token bridge works with the L1 token bridge to enable ERC20 token bridging
///     between L1 and L2. It acts as a minter for new tokens when it hears about
///     deposits into the L1 token bridge. It also acts as a burner of the tokens
///     intended for withdrawal, informing the L1 bridge to release L1 funds.
interface ILidoL2Bridge {
    event WithdrawalInitiated(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    event DepositFinalized(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    event DepositFailed(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    event FailedMessageProcessed(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    /// @notice Returns the address of the corresponding L1 bridge contract
    function lidoL1Bridge() external returns (address);

    /// @notice Initiates a withdraw of some tokens to the caller's account on L1
    /// @param amount_ Amount of the token to withdraw.
    /// @param l1Gas_ Unused, but included for potential forward compatibility considerations.
    /// @param data_ Optional data to forward to L1. This data is provided
    ///     solely as a convenience for external contracts. Aside from enforcing a maximum
    ///     length, these contracts provide no guarantees about its content.
    function withdraw(
        uint256 amount_,
        uint32 l1Gas_,
        bytes calldata data_
    )
    external
    payable;

    /// @notice Initiates a withdraw of some token to a recipient's account on L1.
    /// @param to_ L1 address to credit the withdrawal to.
    /// @param amount_ Amount of the token to withdraw.
    /// @param l1Gas_ Unused, but included for potential forward compatibility considerations.
    /// @param data_ Optional data to forward to L1. This data is provided
    ///     solely as a convenience for external contracts. Aside from enforcing a maximum
    ///     length, these contracts provide no guarantees about its content.
    function withdrawTo(
        address to_,
        uint256 amount_,
        uint32 l1Gas_,
        bytes calldata data_
    )
    external
    payable;

    /// @notice Completes a deposit from L1 to L2, and credits funds to the recipient's balance of
    ///     this L2 token. This call will fail if it did not originate from a corresponding deposit
    ///     in L1StandardTokenBridge.
    /// @param fromBridge_ Address of calling bridge
    /// @param l1Token_ Address for the l1 token this is called with
    /// @param l2Token_ Address for the l2 token this is called with
    /// @param from_ Account to pull the deposit from on L2.
    /// @param to_ Address to receive the withdrawal at
    /// @param amount_ Amount of the token to withdraw
    /// @param data_ Data provider by the sender on L1. This data is provided
    ///     solely as a convenience for external contracts. Aside from enforcing a maximum
    ///     length, these contracts provide no guarantees about its content.
    function finalizeDeposit(
        address fromBridge_,
        address l1Token_,
        address l2Token_,
        address from_,
        address to_,
        uint256 amount_,
        bytes calldata data_
    )
    external;

    /**
     * @notice Handles a failed message
     * @param _message The failed message received
     */
    function handleFailMessage(
        IBridge.Message calldata _message
    )
    external;

    /**
     * @notice Receives and processes a message from the L1 bridge
     * @param _message The message received from the L1 bridge
     * @param _proof The proof of the message
     */
    function receiveMessage(
        IBridge.Message calldata _message,
        bytes calldata _proof
    )
    external;
}
