// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../tokenvault/BaseVault.sol";
import { IBridge } from "../../bridge/IBridge.sol";
import { ILidoL1Bridge } from "./interfaces/ILidoL1Bridge.sol";
import { ILidoL2Bridge } from "./interfaces/ILidoL2Bridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LidoL1Bridge
 * @dev Implementation of the Lido L1 Bridge, extending the ILidoL1Bridge interface and
 * BridgeableTokens contract
 */
contract LidoL1Bridge is ILidoL1Bridge, BaseVault {
    using SafeERC20 for IERC20;

    /// @notice Chain ID of the destination chain
    uint32 destChainId;

    /// @notice Address of the LidoL2Bridge contract on L2
    address public lidoL2Bridge;

    /// @notice Address of the bridged token in the L1 chain
    address public l1Token;

    /// @notice Address of the token minted on the L2 chain when token bridged
    address public l2Token;

    /// @dev Validates that passed l1Token_ is supported by the bridge
    modifier onlySupportedL1Token(address l1Token_) {
        if (l1Token_ != l1Token) {
            revert Lido_UnsupportedL1Token();
        }
        _;
    }

    /// @dev Validates that passed l2Token_ is supported by the bridge
    modifier onlySupportedL2Token(address l2Token_) {
        if (l2Token_ != l2Token) {
            revert Lido_UnsupportedL2Token();
        }
        _;
    }

    /// @dev validates that account_ is not zero address
    modifier onlyNonZeroAccount(address account_) {
        if (account_ == address(0)) {
            revert Lido_AccountIsZeroAddress();
        }
        _;
    }

    uint256[47] private __gap;

    error Lido_notSelf();
    error Lido_notL2Bridge();
    error Lido_messageTampered();
    error Lido_UnsupportedL1Token();
    error Lido_UnsupportedL2Token();
    error Lido_AccountIsZeroAddress();
    error Lido_messageProcessingFailed();

    /**
     * @dev Modifier to restrict function access to only the contract itself
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) revert Lido_notSelf();
        _;
    }

    /// @inheritdoc BaseVault
    function name() public pure override returns (bytes32) {
        return bytes32("Lido L1 Bridge");
    }

    /**
     * @notice Initializes the LidoL1Bridge contract
     * @param _owner The owner of this contract. msg.sender will be used if this value is zero.
     * @param _addressManager The address of the {AddressManager} contract.
     * @param l1Token_ The address of the L1 token
     * @param l2Token_ The address of the L2 token
     * @param dstChainId_ The destination chain ID
     * @param lidoL2TokenBridge_ The address of the Lido L2 bridge
     */
    function init(
        address _owner,
        address _addressManager,
        address l1Token_,
        address l2Token_,
        uint32 dstChainId_,
        address lidoL2TokenBridge_
    )
        external
        initializer
    {
        __Essential_init(_owner, _addressManager);
        l1Token = l1Token_;
        l2Token = l2Token_;
        destChainId = dstChainId_;
        lidoL2Bridge = lidoL2TokenBridge_;
    }

    /// @inheritdoc ILidoL1Bridge
    function deposit(uint256 amount_, uint32 l2Gas_, bytes calldata data_) external payable {
        depositTo(msg.sender, amount_, l2Gas_, data_);
    }

    /// @inheritdoc IMessageInvocable
    function onMessageInvocation(bytes calldata _data) external payable {
        IBridge.Context memory ctx = checkProcessMessageContext();

        (
            address l1Token_,
            address l2Token_,
            address from_,
            address to_,
            uint256 amount_,
            bytes memory data_
        ) = abi.decode(_data, (address, address, address, address, uint256, bytes));

        ILidoL1Bridge(address(this)).finalizeWithdrawal(
            l1Token_, l2Token_, from_, to_, amount_, data_
        );

        emit TokenWithdrawalFinalized(ctx.msgHash, l1Token_, l2Token_, from_, to_, amount_, data_);
    }

    /// @inheritdoc IRecallableSender
    function onMessageRecalled(
        IBridge.Message calldata _message,
        bytes32 _msgHash
    )
        external
        payable
    {
        checkRecallMessageContext();

        (
            address l1Token_,
            address l2Token_,
            address from_,
            address to_,
            uint256 amount_,
            bytes memory data_
        ) = abi.decode(_message.data, (address, address, address, address, uint256, bytes));

        if (l1Token_ != l1Token || l2Token_ != l2Token) revert Lido_messageTampered();

        IERC20(l1Token).safeTransfer(from_, amount_); // Transfer to User

        emit TokenReleaseFinalized(_msgHash, l1Token, l2Token, from_, to_, amount_, data_);
    }

    /// @inheritdoc ILidoL1Bridge
    function finalizeWithdrawal(
        address l1Token_,
        address l2Token_,
        address from_,
        address to_,
        uint256 amount_,
        bytes calldata
    )
        external
        onlySelf
        onlyNonZeroAccount(to_)
        onlyNonZeroAccount(from_)
        onlySupportedL1Token(l1Token_)
        onlySupportedL2Token(l2Token_)
    {
        IERC20(l1Token).safeTransfer(to_, amount_); // Transfer to User
    }

    /// @inheritdoc ILidoL1Bridge
    function depositTo(
        address to_,
        uint256 amount_,
        uint32 l2Gas_,
        bytes calldata data_
    )
        public
        payable
        onlyNonZeroAccount(to_)
    {
        _initiateTokenDeposit(msg.sender, to_, amount_, l2Gas_, msg.value, data_);
    }

    function _initiateTokenDeposit(
        address from_,
        address to_,
        uint256 amount_,
        uint32 l2Gas_,
        uint256 fee_,
        bytes calldata data_
    )
        internal
    {
        IERC20(l1Token).safeTransferFrom(from_, address(this), amount_); // Transfer From user.

        bytes memory message_ = abi.encodeCall(
            this.onMessageInvocation, abi.encode(l1Token, l2Token, from_, to_, amount_, data_)
        );

        // Sends Cross Domain Message

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(this),
            srcChainId: uint64(block.chainid),
            destChainId: destChainId,
            srcOwner: msg.sender,
            destOwner: to_,
            to: lidoL2Bridge,
            value: 0,
            fee: uint64(fee_),
            gasLimit: l2Gas_,
            data: message_
        });

        IBridge(resolve(LibStrings.B_BRIDGE, false)).sendMessage{ value: fee_ }(message);

        emit TokenDepositInitiated(l1Token, l2Token, from_, to_, amount_, data_);
    }
}
