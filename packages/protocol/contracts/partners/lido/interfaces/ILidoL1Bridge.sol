// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @notice The L1 Standard bridge locks bridged tokens on the L1 side, sends deposit messages
///     on the L2 side, and finalizes token withdrawals from L2.
interface ILidoL1Bridge {
    event TokenDepositInitiated(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    event TokenWithdrawalFinalized(
        bytes32 msgHash,
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    event TokenReleaseFinalized(
        bytes32 msgHash,
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    /// @notice get the address of the corresponding L2 bridge contract.
    /// @return Address of the corresponding L2 bridge contract.
    function lidoL2Bridge() external returns (address);

    /// @notice deposit an amount of the ERC20 to the caller's balance on L2.
    /// @param amount_ Amount of the ERC20 to deposit
    /// @param l2Gas_ Gas limit required to complete the deposit on L2.
    /// @param data_ Optional data to forward to L2. This data is provided
    ///        solely as a convenience for external contracts. Aside from enforcing a maximum
    ///        length, these contracts provide no guarantees about its content.
    function deposit(uint256 amount_, uint32 l2Gas_, bytes calldata data_) external payable;

    /// @notice deposit an amount of ERC20 to a recipient's balance on L2.
    /// @param to_ L2 address to credit the withdrawal to.
    /// @param amount_ Amount of the ERC20 to deposit.
    /// @param l2Gas_ Gas limit required to complete the deposit on L2.
    /// @param data_ Optional data to forward to L2. This data is provided
    ///        solely as a convenience for external contracts. Aside from enforcing a maximum
    ///        length, these contracts provide no guarantees about its content.
    function depositTo(
        address to_,
        uint256 amount_,
        uint32 l2Gas_,
        bytes calldata data_
    )
    external
    payable;

    /// @notice Complete a withdrawal from L2 to L1, and credit funds to the recipient's balance of
    /// the
    /// L1 ERC20 token.
    /// @dev This call will fail if the initialized withdrawal from L2 has not been finalized.
    /// @param l1Token_ Address of L1 token to finalizeWithdrawal for.
    /// @param l2Token_ Address of L2 token where withdrawal was initiated.
    /// @param from_ L2 address initiating the transfer.
    /// @param to_ L1 address to credit the withdrawal to.
    /// @param amount_ Amount of the ERC20 to deposit.
    /// @param data_ Data provided by the sender on L2. This data is provided
    ///   solely as a convenience for external contracts. Aside from enforcing a maximum
    ///   length, these contracts provide no guarantees about its content.
    function finalizeWithdrawal(
        address l1Token_,
        address l2Token_,
        address from_,
        address to_,
        uint256 amount_,
        bytes calldata data_
    )
    external;

}
