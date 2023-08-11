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
import { BridgedERC20, ProxiedBridgedERC20 } from "./BridgedERC20.sol";
import { IBridge } from "../bridge/IBridge.sol";
import { IMintableERC20 } from "../common/IMintableERC20.sol";
import { Proxied } from "../common/Proxied.sol";
import { TaikoToken } from "../L1/TaikoToken.sol";
import { LibVaultUtils } from "./libs/LibVaultUtils.sol";
import { EssentialContract } from "../common/EssentialContract.sol";

/**
 * This vault holds all ERC20 tokens (but not Ether) that users have deposited.
 * It also manages the mapping between canonical ERC20 tokens and their bridged
 * tokens.
 * @dev Ether is held by Bridges on L1 and by the EtherVault on L2, not
 * ERC20Vaults.
 */

contract ERC20Vault is EssentialContract {
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

    // Tracks if a token on the current chain is a canonical or btoken.
    mapping(address tokenAddress => bool isBridged) public isBridgedToken;

    // Mappings from btokens to their canonical tokens.
    mapping(address btoken => CanonicalERC20 canonicalErc20) public
        bridgedToCanonical;

    // Mappings from canonical tokens to their btokens.
    // Also storing chainId for tokens across other chains aside from Ethereum.
    mapping(
        uint256 chainId => mapping(address canonicalAddress => address btoken)
    ) public canonicalToBridged;

    // Released message hashes
    mapping(bytes32 msgHash => bool released) public releasedMessages;

    uint256[46] private __gap;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event BridgedTokenDeployed(
        uint256 indexed srcChainId,
        address indexed ctoken,
        address indexed btoken,
        string ctokenSymbol,
        string ctokenName,
        uint8 ctokenDecimal
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

    /**
     * Thrown when the `to` address in an operation is invalid.
     * This can happen if it's zero address or the address of the token vault.
     */
    error VAULT_INVALID_TO();

    /**
     * Thrown when the token address in a transaction is invalid.
     * This could happen if the token address is zero or doesn't conform to the
     * ERC20 standard.
     */
    error VAULT_INVALID_TOKEN();

    /**
     * Thrown when the amount in a transaction is invalid.
     * This could happen if the amount is zero or exceeds the sender's balance.
     */
    error VAULT_INVALID_AMOUNT();

    /**
     * Thrown when the owner address in a message is invalid.
     * This could happen if the owner address is zero or doesn't match the
     * expected owner.
     */
    error VAULT_INVALID_OWNER();

    /**
     * Thrown when the sender in a message context is invalid.
     * This could happen if the sender isn't the expected token vault on the
     * source chain.
     */
    error VAULT_INVALID_SENDER();

    /**
     * Thrown when the source chain ID in a message is invalid.
     * This could happen if the source chain ID doesn't match the current
     * chain's ID.
     */
    error VAULT_INVALID_SRC_CHAIN_ID();

    /**
     * Thrown when a message has not failed.
     * This could happen if trying to release a message deposit without proof of
     * failure.
     */
    error VAULT_MESSAGE_NOT_FAILED();

    /**
     * Thrown when a message has already released
     */
    error VAULT_MESSAGE_RELEASED_ALREADY();

    modifier onlyValidAddresses(
        uint256 chainId,
        bytes32 name,
        address to,
        address token
    ) {
        if (to == address(0) || to == resolve(chainId, name, false)) {
            revert VAULT_INVALID_TO();
        }

        if (token == address(0)) revert VAULT_INVALID_TOKEN();
        _;
    }

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

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
     * @param ctoken The canonical ERC20 token which may or may not
     * live on this chain. If not, a BridgedERC20 contract will be deployed.
     * @param from The source address.
     * @param to The destination address.
     * @param amount The amount of tokens to be sent. 0 is a valid value.
     */
    function receiveToken(
        CanonicalERC20 calldata ctoken,
        address from,
        address to,
        uint256 amount
    )
        external
        nonReentrant
        onlyFromNamed("bridge")
    {
        IBridge.Context memory ctx =
            LibVaultUtils.checkValidContext("erc20_vault", address(this));

        address token;
        if (ctoken.chainId == block.chainid) {
            token = ctoken.addr;
            if (token == resolve("taiko_token", true)) {
                IMintableERC20(token).mint(to, amount);
            } else {
                ERC20Upgradeable(token).safeTransfer(to, amount);
            }
        } else {
            token = _getOrDeployBridgedToken(ctoken);
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

        if (releasedMessages[msgHash]) {
            revert VAULT_MESSAGE_RELEASED_ALREADY();
        }
        releasedMessages[msgHash] = true;

        (, address token,, uint256 amount) = abi.decode(
            message.data[4:], (CanonicalERC20, address, address, uint256)
        );

        if (token == address(0)) revert VAULT_INVALID_TOKEN();

        if (!bridge.isMessageFailed(msgHash, message.destChainId, proof)) {
            revert VAULT_MESSAGE_NOT_FAILED();
        }

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
        returns (bytes memory msgData, uint256 _amount)
    {
        CanonicalERC20 memory ctoken;

        // is a btoken, meaning, it does not live on this chain
        if (isBridgedToken[token]) {
            ctoken = bridgedToCanonical[token];
            assert(ctoken.addr != address(0));
            IMintableERC20(token).burn(msg.sender, amount);
            _amount = amount;
        } else {
            // is a canonical token, meaning, it lives on this chain
            ERC20Upgradeable t = ERC20Upgradeable(token);
            ctoken = CanonicalERC20({
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
                t.transferFrom({
                    from: msg.sender,
                    to: address(this),
                    amount: amount
                });
                _amount = t.balanceOf(address(this)) - _balance;
            }
        }

        msgData = abi.encodeWithSelector(
            ERC20Vault.receiveToken.selector, ctoken, owner, to, _amount
        );
    }

    /**
     * Internal function to get or deploy btoken
     * @param ctoken Canonical token information
     * @return btoken Address of the deployed btoken
     */
    function _getOrDeployBridgedToken(CanonicalERC20 calldata ctoken)
        private
        returns (address btoken)
    {
        btoken = canonicalToBridged[ctoken.chainId][ctoken.addr];

        if (btoken == address(0)) {
            btoken = _deployBridgedToken(ctoken);
        }
    }

    /**
     * Internal function to deploy a new BridgedERC20 contract and initializes
     * it.
     * This must be called before the first time a btoken is sent to this
     * chain.
     * @param ctoken Canonical token information
     * @return btoken Address of the newly deployed btoken
     */
    function _deployBridgedToken(CanonicalERC20 calldata ctoken)
        private
        returns (address btoken)
    {
        ProxiedBridgedERC20 bridgedToken = new ProxiedBridgedERC20();

        btoken = LibVaultUtils.deployProxy(
            address(bridgedToken),
            owner(),
            bytes.concat(
                bridgedToken.init.selector,
                abi.encode(
                    address(_addressManager),
                    ctoken.addr,
                    ctoken.chainId,
                    ctoken.decimals,
                    ctoken.symbol,
                    ctoken.name
                )
            )
        );

        isBridgedToken[btoken] = true;
        bridgedToCanonical[btoken] = ctoken;
        canonicalToBridged[ctoken.chainId][ctoken.addr] = btoken;

        emit BridgedTokenDeployed({
            srcChainId: ctoken.chainId,
            ctoken: ctoken.addr,
            btoken: btoken,
            ctokenSymbol: ctoken.symbol,
            ctokenName: ctoken.name,
            ctokenDecimal: ctoken.decimals
        });
    }
}

contract ProxiedERC20Vault is Proxied, ERC20Vault { }
