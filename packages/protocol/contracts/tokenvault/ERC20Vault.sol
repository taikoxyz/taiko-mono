// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {
    IERC20Upgradeable,
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { Create2Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import { BridgedERC20 } from "./BridgedERC20.sol";
import { IBridge } from "../bridge/IBridge.sol";
import { IMintableERC20 } from "../common/IMintableERC20.sol";
import { Proxied } from "../common/Proxied.sol";
import { TaikoToken } from "../L1/TaikoToken.sol";
import { BaseVault } from "./BaseVault.sol";
/**
 * This vault holds all ERC20 tokens (but not Ether) that users have deposited.
 * It also manages the mapping between canonical ERC20 tokens and their bridged
 * tokens.
 * @dev Ether is held by Bridges on L1 and by the EtherVault on L2, not
 * ERC20Vaults.
 * @custom:security-contact hello@taiko.xyz
 */

contract ERC20Vault is BaseVault {
    using SafeERC20Upgradeable for ERC20Upgradeable;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct CanonicalERC20 {
        uint256 chainId;
        address addr;
        uint8 decimals;
        string symbol;
        string name;
    }

    struct MessageDeposit {
        address token;
        uint256 amount;
    }

    struct BridgeTransferOp {
        uint256 destChainId;
        address to;
        address token;
        uint256 amount;
        uint256 gasLimit;
        uint256 processingFee;
        address refundAddress;
        string memo;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Tracks if a token on the current chain is a canonical or bridged token.
    mapping(address tokenAddress => bool isBridged) public isBridgedToken;

    // Mappings from bridged tokens to their canonical tokens.
    mapping(address bridgedAddress => CanonicalERC20 canonicalErc20) public
        bridgedToCanonical;

    // Mappings from canonical tokens to their bridged tokens.
    // Also storing chainId for tokens across other chains aside from Ethereum.
    mapping(
        uint256 chainId
            => mapping(address canonicalAddress => address bridgedAddress)
    ) public canonicalToBridged;

    // Tracks the token and amount associated with a message hash.
    mapping(bytes32 msgHash => MessageDeposit messageDeposit) public
        messageDeposits;

    uint256[46] private __gap;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event BridgedTokenDeployed(
        uint256 indexed srcChainId,
        address indexed canonicalToken,
        address indexed bridgedToken,
        string canonicalTokenSymbol,
        string canonicalTokenName,
        uint8 canonicalTokenDecimal
    );

    event TokenSent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 destChainId,
        address token,
        uint256 amount
    );

    event TokenReleased(
        bytes32 indexed msgHash,
        address indexed from,
        address token,
        uint256 amount
    );

    event TokenReceived(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 srcChainId,
        address token,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                         USER-FACING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * Transfers ERC20 tokens to this vault and sends a message to the
     * destination chain so the user can receive the same amount of tokens
     * by invoking the message call.
     *
     * @param opt Option for sending ERC20 tokens.
     */

    function sendToken(BridgeTransferOp calldata opt)
        external
        payable
        nonReentrant
        onlyValidAddresses(opt.destChainId, "erc20_vault", opt.to, opt.token)
    {
        if (opt.amount == 0) revert VAULT_INVALID_AMOUNT();

        uint256 _amount;
        IBridge.Message memory message;

        (message.data, _amount) = _sendToken({
            owner: message.owner,
            token: opt.token,
            amount: opt.amount,
            to: opt.to
        });

        message.destChainId = opt.destChainId;
        message.owner = msg.sender;
        message.to = resolve(opt.destChainId, "erc20_vault", false);
        message.gasLimit = opt.gasLimit;
        message.processingFee = opt.processingFee;
        message.depositValue = msg.value - opt.processingFee;
        message.refundAddress = opt.refundAddress;
        message.memo = opt.memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        // record the deposit for this message
        messageDeposits[msgHash] = MessageDeposit(opt.token, _amount);

        emit TokenSent({
            msgHash: msgHash,
            from: message.owner,
            to: opt.to,
            destChainId: opt.destChainId,
            token: opt.token,
            amount: _amount
        });
    }

    /**
     * This function can only be called by the bridge contract while
     * invoking a message call. See sendToken, which sets the data to invoke
     * this function.
     *
     * @param canonicalToken The canonical ERC20 token which may or may not
     * live on this chain. If not, a BridgedERC20 contract will be deployed.
     * @param from The source address.
     * @param to The destination address.
     * @param amount The amount of tokens to be sent. 0 is a valid value.
     */
    function receiveToken(
        CanonicalERC20 calldata canonicalToken,
        address from,
        address to,
        uint256 amount
    )
        external
        nonReentrant
        onlyFromNamed("bridge")
    {
        IBridge.Context memory ctx = _checkValidContext("erc20_vault");

        address token;
        if (canonicalToken.chainId == block.chainid) {
            token = canonicalToken.addr;
            if (token == resolve("taiko_token", true)) {
                IMintableERC20(token).mint(to, amount);
            } else {
                ERC20Upgradeable(token).safeTransfer(to, amount);
            }
        } else {
            token = _getOrDeployBridgedToken(canonicalToken);
            IMintableERC20(token).mint(to, amount);
        }

        emit TokenReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            token: token,
            amount: amount
        });
    }

    /**
     * Release deposited ERC20 back to the owner on the source ERC20Vault with
     * a proof that the message processing on the destination Bridge has failed.
     *
     * @param message The message that corresponds to the ERC20 deposit on the
     * source chain.
     * @param proof The proof from the destination chain to show the message has
     * failed.
     */
    function releaseToken(
        IBridge.Message calldata message,
        bytes calldata proof
    )
        external
        nonReentrant
    {
        if (message.owner == address(0)) revert VAULT_INVALID_OWNER();
        if (message.srcChainId != block.chainid) {
            revert VAULT_INVALID_SRC_CHAIN_ID();
        }

        IBridge bridge = IBridge(resolve("bridge", false));
        bytes32 msgHash = bridge.hashMessage(message);

        address token = messageDeposits[msgHash].token;
        uint256 amount = messageDeposits[msgHash].amount;
        if (token == address(0)) revert VAULT_INVALID_TOKEN();

        if (!bridge.isMessageFailed(msgHash, message.destChainId, proof)) {
            revert VAULT_MESSAGE_NOT_FAILED();
        }

        messageDeposits[msgHash] = MessageDeposit(address(0), 0);

        if (amount > 0) {
            if (isBridgedToken[token] || token == resolve("taiko_token", true))
            {
                IMintableERC20(token).mint(message.owner, amount);
            } else {
                ERC20Upgradeable(token).safeTransfer(message.owner, amount);
            }
        }

        emit TokenReleased({
            msgHash: msgHash,
            from: message.owner,
            token: token,
            amount: amount
        });
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _sendToken(
        address owner,
        address token,
        address to,
        uint256 amount
    )
        private
        returns (bytes memory data, uint256 _amount)
    {
        CanonicalERC20 memory canonicalToken;

        // is a bridged token, meaning, it does not live on this chain
        if (isBridgedToken[token]) {
            canonicalToken = bridgedToCanonical[token];
            assert(canonicalToken.addr != address(0));
            IMintableERC20(token).burn(msg.sender, amount);
            _amount = amount;
        } else {
            // is a canonical token, meaning, it lives on this chain
            ERC20Upgradeable t = ERC20Upgradeable(token);
            canonicalToken = CanonicalERC20({
                chainId: block.chainid,
                addr: token,
                decimals: t.decimals(),
                symbol: t.symbol(),
                name: t.name()
            });

            if (token == resolve("taiko_token", true)) {
                IMintableERC20(token).burn(msg.sender, amount);
                _amount = amount;
            } else {
                uint256 _balance = t.balanceOf(address(this));
                t.safeTransferFrom(msg.sender, address(this), amount);
                _amount = t.balanceOf(address(this)) - _balance;
            }
        }

        data = abi.encodeWithSelector(
            ERC20Vault.receiveToken.selector, canonicalToken, owner, to, _amount
        );
    }

    /**
     * Internal function to get or deploy bridged token
     * @param canonicalToken Canonical token information
     * @return token Address of the deployed bridged token
     */
    function _getOrDeployBridgedToken(CanonicalERC20 calldata canonicalToken)
        private
        returns (address)
    {
        address token =
            canonicalToBridged[canonicalToken.chainId][canonicalToken.addr];

        return token != address(0) ? token : _deployBridgedToken(canonicalToken);
    }

    /**
     * Internal function to deploy a new BridgedERC20 contract and initializes
     * it.
     * This must be called before the first time a bridged token is sent to this
     * chain.
     * @param canonicalToken Canonical token information
     * @return bridgedToken Address of the newly deployed bridged token
     */
    function _deployBridgedToken(CanonicalERC20 calldata canonicalToken)
        private
        returns (address bridgedToken)
    {
        bridgedToken = Create2Upgradeable.deploy(
            0, // amount of Ether to send
            keccak256(
                bytes.concat(
                    bytes32(canonicalToken.chainId),
                    bytes32(uint256(uint160(canonicalToken.addr)))
                )
            ),
            type(BridgedERC20).creationCode
        );

        BridgedERC20(payable(bridgedToken)).init({
            _addressManager: address(_addressManager),
            _srcToken: canonicalToken.addr,
            _srcChainId: canonicalToken.chainId,
            _decimals: canonicalToken.decimals,
            _symbol: canonicalToken.symbol,
            _name: canonicalToken.name
        });

        isBridgedToken[bridgedToken] = true;
        bridgedToCanonical[bridgedToken] = canonicalToken;
        canonicalToBridged[canonicalToken.chainId][canonicalToken.addr] =
            bridgedToken;

        emit BridgedTokenDeployed({
            srcChainId: canonicalToken.chainId,
            canonicalToken: canonicalToken.addr,
            bridgedToken: bridgedToken,
            canonicalTokenSymbol: canonicalToken.symbol,
            canonicalTokenName: canonicalToken.name,
            canonicalTokenDecimal: canonicalToken.decimals
        });
    }
}

contract ProxiedERC20Vault is Proxied, ERC20Vault { }
