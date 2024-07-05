// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../tokenvault/BaseVault.sol";
import { Bridge } from "../../bridge/Bridge.sol";
import { IBridge } from "../../bridge/IBridge.sol";
import { ILidoL1Bridge } from "./interfaces/ILidoL1Bridge.sol";
import { ILidoL2Bridge } from "./interfaces/ILidoL2Bridge.sol";
import { ILidoBridgedToken } from "./interfaces/ILidoBridgedToken.sol";

contract LidoL2Bridge is ILidoL2Bridge, BaseVault {

    /// @notice Chain ID of the destination chain
    uint32 destChainId;

    /// @notice Address of the LidoL1Bridge contract on L1
    address public lidoL1Bridge;

    /// @notice Instance of the bridged Lido token interface
    ILidoBridgedToken bridgedToken;

    /// @notice Address of the bridged token in the L1 chain
    address public l1Token;

    /// @notice Address of the token minted on the L2 chain when token bridged
    address public l2Token;

    uint256[47] private __gap;

    /**
     * @dev Modifier to restrict function access to only the contract itself
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) revert Lido_notSelf();
        _;
    }

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

    error Lido_notSelf();
    error Lido_messageTampered();
    error Lido_UnsupportedL1Token();
    error Lido_UnsupportedL2Token();
    error Lido_AccountIsZeroAddress();

    /**
     * @notice Initializes the LidoL2Bridge contract
     * @param _owner The owner of this contract. msg.sender will be used if this value is zero.
     * @param _addressManager The address of the {AddressManager} contract.
     * @param l1Token_ The address of the L1 token
     * @param l2Token_ The address of the L2 token
     * @param dstChainId_ The destination chain ID
     * @param bridgedToken_ The address of the bridged token contract
     * @param lidoL1TokenBridge_ The address of the Lido L1 bridge contract
    */
    function init(
        address _owner,
        address _addressManager,
        address l1Token_,
        address l2Token_,
        uint32 dstChainId_,
        address bridgedToken_,
        address lidoL1TokenBridge_
    )
    external
    initializer
    {
        __Essential_init(_owner, _addressManager);
        destChainId = dstChainId_;
        l1Token = l1Token_;
        l2Token = l2Token_;
        lidoL1Bridge = lidoL1TokenBridge_;
        bridgedToken = ILidoBridgedToken(bridgedToken_);
    }

    /// @inheritdoc BaseVault
    function name() public pure override returns (bytes32) {
        return bytes32("Lido L2 Bridge");
    }

    /// @inheritdoc ILidoL2Bridge
    function withdraw(
        uint256 amount_,
        uint32 l1Gas_,
        bytes calldata data_
    )
    external
    payable
    {
        withdrawTo(msg.sender, amount_, l1Gas_, data_);
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

        ILidoL2Bridge(address(this)).finalizeDeposit(
            l1Token_, l2Token_, from_, to_, amount_, data_
        );

        emit DepositFinalized(
            ctx.msgHash,
            l1Token_,
            l2Token_,
            from_,
            to_,
            amount_,
            data_
        );
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

        if (l1Token_ != l1Token || l2Token_ != l2Token) {
            revert Lido_messageTampered();
        }

        bridgedToken.bridgeMint(from_, amount_);

        emit TokenReleaseFinalized(
            _msgHash,
            l1Token,
            l2Token,
            from_,
            to_,
            amount_,
            data_
        );
    }

    /// @inheritdoc ILidoL2Bridge
    function finalizeDeposit(
        address l1Token_,
        address l2Token_,
        address from_,
        address to_,
        uint256 amount_,
        bytes calldata
    )
    external
    onlySelf
    onlyNonZeroAccount(from_)
    onlyNonZeroAccount(to_)
    onlySupportedL1Token(l1Token_)
    onlySupportedL2Token(l2Token_)
    {
        bridgedToken.bridgeMint(to_, amount_);
    }

    /// @inheritdoc ILidoL2Bridge
    function withdrawTo(
        address to_,
        uint256 amount_,
        uint32 l1Gas_,
        bytes calldata data_
    )
    public
    payable
    {
        _initiateWithdrawal(msg.sender, to_, amount_, l1Gas_, msg.value, data_);
    }

    function _initiateWithdrawal(
        address from_,
        address to_,
        uint256 amount_,
        uint32 l1Gas_,
        uint256 fee_,
        bytes calldata data_
    )
    internal
    {
        bridgedToken.bridgeBurn(from_, amount_);

        bytes memory message_ = abi.encodeCall(
            this.onMessageInvocation, abi.encode(l1Token, l2Token, from_, to_, amount_, data_)
        );

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(this),
            srcChainId: uint64(block.chainid),
            destChainId: destChainId,
            srcOwner: from_,
            destOwner: to_,
            to: lidoL1Bridge,
            value: 0,
            fee: uint64(fee_),
            gasLimit: l1Gas_,
            data: message_
        });

        IBridge(resolve(LibStrings.B_BRIDGE, false)).sendMessage{ value: fee_ }(message);

        emit WithdrawalInitiated(
            l1Token,
            l2Token,
            from_,
            to_,
            amount_,
            data_
        );
    }
}
