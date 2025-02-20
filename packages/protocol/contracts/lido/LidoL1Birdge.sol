// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { BridgingManagerEnumerable } from "./base/BridgingManagerEnumerable.sol";
import { ITaikoBasicBridge } from "../shared/bridge/ITaikoBasicBridge.sol";
import "../shared/common/LibStrings.sol";

/// @notice The L1 ERC20 token bridge locks bridged tokens on the L1 side, sends deposit messages
///     on the L2 side, and finalizes token withdrawals from L2. Additionally, adds the methods for
///     bridging management: enabling and disabling withdrawals/deposits
contract LidoL1Bridge is BridgingManagerEnumerable {
    using SafeERC20 for IERC20;

    address public l1token;
    address public l2token;
    address public counterpart;


    //todooooo
    // / @param messenger_ L1 messenger address being used for cross-chain communications
    // / @param l2TokenBridge_ Address of the corresponding L2 bridge
    // / @param l1Token_ Address of the bridged token in the L1 chain
    // / @param l2Token_ Address of the token minted on the L2 chain when token bridged
    function initialize(
        address counterpart_,
        address l1Token_,
        address l2Token_ ,
        address _owner,
        address _sharedAddressManager)
    external
    initializer
    {
        __Essential_init(_owner, _sharedAddressManager);
        counterpart = counterpart_;
        l1token = l1Token_;
        l2token = l2Token_;
    }




    function depositERC20(uint256 amount_,uint32 gasLimit_,uint64 destChainId) external payable whenDepositsEnabled {
        if (Address.isContract(msg.sender)) {
            revert ErrorSenderNotEOA();
        }
        _initiateERC20Deposit(msg.sender, msg.sender, amount_,uint64(msg.value),gasLimit_,destChainId);
    }

    function depositERC20To(
        address to_,
        uint256 amount_,
        uint32 gasLimit_,
        uint64 destChainId
    )
    external
    payable
    whenDepositsEnabled
    onlyNonZeroAccount(to_)
    {
        _initiateERC20Deposit(msg.sender, to_, amount_, uint64(msg.value),gasLimit_,destChainId);
    }

    function onMessageInvocation(bytes calldata _data)
    override
    external

    whenWithdrawalsEnabled
    nonReentrant
    onlyFromNamed(LibStrings.B_BRIDGE)
    {

        ( address from, address to, uint256 amount) =
                            abi.decode(_data, ( address, address, uint256));

        _finalizeERC20Withdrawal(from, to, amount);
    }


    //todo mwrite proper doc
    // /**
    //  * @dev Performs the logic for deposits by informing the L2 Deposited Token
    //  * contract of the deposit and calling a handler to lock the L1 funds. (e.g. transferFrom)
    //  *
    //  * @param from_ Account to pull the deposit from on L1
    //  * @param to_ Account to give the deposit to on L2
    //  * @param amount_ Amount of the ERC20 to deposit.
    //  * @param l2Gas_ Gas limit required to complete the deposit on L2,
    //  *        it should equal to or large than oracle.getMinL2Gas(),
    //  *        user should send at least l2Gas_ * oracle.getDiscount().
    //  *        oracle.getDiscount returns gas price. At time of writing, it is set to zero and is
    //  * planned to stay so.
    //  *        Bridging tokens and coins require paying fees, and there is the defined minimal L2 Gas
    //  * limit,
    //  *        which may make the defined by user Gas value increase.
    //  */
    function _initiateERC20Deposit(
        address from_,
        address to_,
        uint256 amount_,
        uint64 fee_,
        uint32 gasLimit_,
        uint64 destChainId_
    )
    internal
    {
        if (amount_ == 0) {
            revert ErrorZeroAmount();
        }
        if (msg.value < fee_) revert ErrorInsufficientFee();


        IERC20(l1token).safeTransferFrom(from_, address(this), amount_);

        bytes memory msgData_ = abi.encodeCall(
            this.onMessageInvocation, abi.encode( msg.sender, to_, amount_)
        );

        ITaikoBasicBridge.Message memory message = ITaikoBasicBridge.Message({
            id: 0,
            from: address(0), // will receive a new value
            srcChainId: 0, // will receive a new value
            destChainId: destChainId_,
            srcOwner: msg.sender,
            destOwner: to_,
            to: counterpart,
            value: 0,
            fee: fee_,
            gasLimit: gasLimit_,
            data: msgData_
        });
        ITaikoBasicBridge(resolve(LibStrings.B_BRIDGE, false)).sendMessage{ value: msg.value }(message);
        emit ERC20DepositInitiated(l1token, l2token, from_, to_, amount_);
    }

    function _finalizeERC20Withdrawal(address from_, address to_, uint256 amount_) internal {
        // When a withdrawal is finalized on L1, the L1 Bridge transfers the funds to the withdrawer
        IERC20(l1token).safeTransfer(to_, amount_);
        emit ERC20WithdrawalFinalized(l1token, l2token, from_, to_, amount_);
    }

    error ErrorSenderNotEOA();
    error ErrorZeroAmount();
    error ErrorInsufficientFee();

}
