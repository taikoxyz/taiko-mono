// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

// solhint-disable-next-line max-line-length
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";

import "../common/EssentialContract.sol";
import "../L1/TkoToken.sol";
import "./BridgedERC20.sol";
import "./IBridge.sol";

/**
 * This vault holds all ERC20 tokens (but not Ether) that users have deposited.
 * It also manages the mapping between canonical ERC20 tokens and their bridged
 * tokens.
 *
 * @author dantaik <dan@taiko.xyz>
 */
contract TokenVault is EssentialContract {
    using SafeERC20Upgradeable for ERC20Upgradeable;

    /*********************
     * Structs           *
     *********************/

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

    /*********************
     * Errors            *
     *********************/

    error ErrInvalidToAddress();
    error ErrInvalidToken();
    error ErrInvalidAmount();
    error ErrInvalidMsgValue();
    error ErrInvalidMsgCallValue();
    error ErrInvalidMsgOwner();
    error ErrInvalidMsgStatus();
    error ErrInvalidMsgSrcChain();
    error ErrERC20TokenReleasedAlready();
    error ErrMsgSenderNotTokenVault();

    /*********************
     * State Variables   *
     *********************/

    // Tracks if a token on the current chain is a canoncial or bridged token.
    mapping(address => bool) public isBridgedToken;

    // Mappings from bridged tokens to their canonical tokens.
    mapping(address => CanonicalERC20) public bridgedToCanonical;

    // Mappings from canonical tokens to their bridged tokens.
    // chainId => canonical address => bridged address
    mapping(uint256 => mapping(address => address)) public canonicalToBridged;

    mapping(bytes32 => MessageDeposit) public messageDeposits;

    uint256[47] private __gap;

    /*********************
     * Events            *
     *********************/

    event BridgedERC20Deployed(
        uint256 indexed srcChainId,
        address indexed canonicalToken,
        address indexed bridgedToken,
        string canonicalTokenSymbol,
        string canonicalTokenName,
        uint8 canonicalTokenDecimal
    );

    event EtherSent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 destChainId,
        uint256 amount
    );

    event ERC20Sent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 destChainId,
        address token,
        uint256 amount
    );

    event ERC20Released(
        bytes32 indexed msgHash,
        address indexed from,
        address token,
        uint256 amount
    );
    event ERC20Received(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 srcChainId,
        address token,
        uint256 amount
    );

    /*********************
     * External Functions*
     *********************/

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /**
     * Transfers Ether to this vault and sends a message to the destination
     * chain so the user can receive Ether.
     *
     * @dev Ether is held by Bridges on L1 and by the EtherVault on L2,
     *      not TokenVaults.
     * @param destChainId The destination chain ID where the `to` address lives.
     * @param to The destination address.
     * @param processingFee @custom:see Bridge
     */
    function sendEther(
        uint256 destChainId,
        address to,
        uint256 gasLimit,
        uint256 processingFee,
        address refundAddress,
        string memory memo
    ) external payable nonReentrant {
        if (
            to == address(0) || to == resolve(destChainId, "token_vault", false)
        ) {
            revert ErrInvalidToAddress();
        }
        if (msg.value <= processingFee) {
            revert ErrInvalidMsgValue();
        }

        IBridge.Message memory message;
        message.destChainId = destChainId;
        message.owner = msg.sender;
        message.to = to;

        message.gasLimit = gasLimit;
        message.processingFee = processingFee;
        message.depositValue = msg.value - processingFee;
        message.refundAddress = refundAddress;
        message.memo = memo;

        if (message.callValue != 0) {
            revert ErrInvalidMsgCallValue();
        }

        // Ether are held by the Bridge on L1 and by the EtherVault on L2, not
        // the TokenVault
        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        emit EtherSent({
            msgHash: msgHash,
            from: message.owner,
            to: message.to,
            destChainId: destChainId,
            amount: message.depositValue
        });
    }

    /**
     * Transfers ERC20 tokens to this vault and sends a message to the
     * destination chain so the user can receive the same amount of tokens
     * by invoking the message call.
     *
     * @param token The address of the token to be sent.
     * @param destChainId The destination chain ID where the `to` address lives.
     * @param to The destination address.
     * @param refundAddress The fee refund address. If this address is
     *        address(0), extra fees will be refunded back to the `to` address.
     * @param amount The amount of token to be transferred.
     * @param processingFee @custom:see Bridge
     * @param gasLimit @custom:see Bridge
     */
    function sendERC20(
        uint256 destChainId,
        address to,
        address token,
        uint256 amount,
        uint256 gasLimit,
        uint256 processingFee,
        address refundAddress,
        string memory memo
    ) external payable nonReentrant {
        if (
            to == address(0) || to == resolve(destChainId, "token_vault", false)
        ) {
            revert ErrInvalidToAddress();
        }
        if (token == address(0)) revert ErrInvalidToken();
        if (amount == 0) revert ErrInvalidAmount();

        CanonicalERC20 memory canonicalToken;
        uint256 _amount;

        if (isBridgedToken[token]) {
            BridgedERC20(token).bridgeBurnFrom(msg.sender, amount);
            canonicalToken = bridgedToCanonical[token];
            assert(canonicalToken.addr != address(0));
            _amount = amount;
        } else {
            // The canonical token lives on this chain
            ERC20Upgradeable t = ERC20Upgradeable(token);
            canonicalToken = CanonicalERC20({
                chainId: block.chainid,
                addr: token,
                decimals: t.decimals(),
                symbol: t.symbol(),
                name: t.name()
            });

            uint256 _balance = t.balanceOf(address(this));
            t.safeTransferFrom(msg.sender, address(this), amount);
            _amount = t.balanceOf(address(this)) - _balance;
        }

        IBridge.Message memory message;
        message.destChainId = destChainId;
        message.owner = msg.sender;

        message.to = resolve(destChainId, "token_vault", false);
        message.data = abi.encodeWithSelector(
            TokenVault.receiveERC20.selector,
            canonicalToken,
            message.owner,
            to,
            _amount
        );

        message.gasLimit = gasLimit;
        message.processingFee = processingFee;
        message.depositValue = msg.value - processingFee;
        message.refundAddress = refundAddress;
        message.memo = memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        messageDeposits[msgHash] = MessageDeposit(token, _amount);

        emit ERC20Sent({
            msgHash: msgHash,
            from: message.owner,
            to: to,
            destChainId: destChainId,
            token: token,
            amount: _amount
        });
    }

    /**
     * Release deposited ERC20 back to the owner on the source TokenVault with
     * a proof that the message processing on the destination Bridge has failed.
     *
     * @param message The message that corresponds the ERC20 deposit on the
     *                source chain.
     * @param proof The proof from the destination chain to show the message
     *              has failed.
     */

    function releaseERC20(
        IBridge.Message calldata message,
        bytes calldata proof
    ) external nonReentrant {
        if (message.owner == address(0)) revert ErrInvalidMsgOwner();
        if (message.srcChainId != block.chainid) revert ErrInvalidMsgSrcChain();

        IBridge bridge = IBridge(resolve("bridge", false));
        bytes32 msgHash = bridge.hashMessage(message);

        address token = messageDeposits[msgHash].token;
        uint256 amount = messageDeposits[msgHash].amount;
        if (token == address(0)) revert ErrERC20TokenReleasedAlready();
        if (!bridge.isMessageFailed(msgHash, message.destChainId, proof)) {
            revert ErrInvalidMsgStatus();
        }

        messageDeposits[msgHash] = MessageDeposit(address(0), 0);

        if (amount > 0) {
            if (isBridgedToken[token]) {
                BridgedERC20(token).bridgeMintTo(message.owner, amount);
            } else {
                ERC20Upgradeable(token).safeTransfer(message.owner, amount);
            }
        }

        emit ERC20Released({
            msgHash: msgHash,
            from: message.owner,
            token: token,
            amount: amount
        });
    }

    /**
     * @dev This function can only be called by the bridge contract while
     *      invoking a message call.
     * @param canonicalToken The canonical ERC20 token which may or may not
     *        live on this chain. If not, a BridgedERC20 contract will be
     *        deployed.
     * @param from The source address.
     * @param to The destination address.
     * @param amount The amount of tokens to be sent. 0 is a valid value.
     */
    function receiveERC20(
        CanonicalERC20 calldata canonicalToken,
        address from,
        address to,
        uint256 amount
    ) external nonReentrant onlyFromNamed("bridge") {
        IBridge.Context memory ctx = IBridge(msg.sender).context();
        if (ctx.sender != resolve(ctx.srcChainId, "token_vault", false)) {
            revert ErrMsgSenderNotTokenVault();
        }

        address token;
        if (canonicalToken.chainId == block.chainid) {
            token = canonicalToken.addr;
            ERC20Upgradeable(token).safeTransfer(to, amount);
        } else {
            token = _getOrDeployBridgedToken(canonicalToken);
            BridgedERC20(token).bridgeMintTo(to, amount);
        }

        emit ERC20Received({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            token: token,
            amount: amount
        });
    }

    /*********************
     * Private Functions *
     *********************/

    function _getOrDeployBridgedToken(
        CanonicalERC20 calldata canonicalToken
    ) private returns (address) {
        address token = canonicalToBridged[canonicalToken.chainId][
            canonicalToken.addr
        ];

        return
            token != address(0) ? token : _deployBridgedToken(canonicalToken);
    }

    function _deployBridgedToken(
        CanonicalERC20 calldata canonicalToken
    ) private returns (address bridgedToken) {
        bytes32 salt = keccak256(
            abi.encodePacked(canonicalToken.chainId, canonicalToken.addr)
        );
        bridgedToken = Create2Upgradeable.deploy(
            0, // amount of Ether to send
            salt,
            type(BridgedERC20).creationCode
        );

        BridgedERC20(payable(bridgedToken)).init({
            _addressManager: address(_addressManager),
            _srcToken: canonicalToken.addr,
            _srcChainId: canonicalToken.chainId,
            _decimals: canonicalToken.decimals,
            _symbol: canonicalToken.symbol,
            _name: string(
                abi.encodePacked(
                    canonicalToken.name,
                    "(bridged",
                    hex"F09F8C88", // 🌈
                    canonicalToken.chainId,
                    ")"
                )
            )
        });

        isBridgedToken[bridgedToken] = true;
        bridgedToCanonical[bridgedToken] = canonicalToken;
        canonicalToBridged[canonicalToken.chainId][
            canonicalToken.addr
        ] = bridgedToken;

        emit BridgedERC20Deployed({
            srcChainId: canonicalToken.chainId,
            canonicalToken: canonicalToken.addr,
            bridgedToken: bridgedToken,
            canonicalTokenSymbol: canonicalToken.symbol,
            canonicalTokenName: canonicalToken.name,
            canonicalTokenDecimal: canonicalToken.decimals
        });
    }
}
