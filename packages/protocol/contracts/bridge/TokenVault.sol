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
 * @dev Ether is held by Bridges on L1 and by the EtherVault on L2,
 * not TokenVaults.
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
     * State Variables   *
     *********************/

    // Tracks if a token on the current chain is a canonical or bridged token.
    mapping(address => bool) public isBridgedToken;

    // Mappings from bridged tokens to their canonical tokens.
    mapping(address => CanonicalERC20) public bridgedToCanonical;

    // Mappings from canonical tokens to their bridged tokens.
    // Also storing chainId for tokens across other chains aside from Ethereum.
    // chainId => canonical address => bridged address
    mapping(uint256 => mapping(address => address)) public canonicalToBridged;

    // Tracks the token and amount associated with a message hash.
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
     * Receives Ether and constructs a Bridge message. Sends the Ether and
     * message along to the Bridge.
     * @param destChainId @custom:see IBridge.Message
     * @param to @custom:see IBridge.Message
     * @param gasLimit @custom:see IBridge.Message
     * @param processingFee @custom:see IBridge.Message
     * @param refundAddress @custom:see IBridge.Message
     * @param memo @custom:see IBridge.Message
     */
    function sendEther(
        uint256 destChainId,
        address to,
        uint256 gasLimit,
        uint256 processingFee,
        address refundAddress,
        string memory memo
    ) external payable nonReentrant {
        require(
            to != address(0) &&
                to != resolve(destChainId, "token_vault", false),
            "V:to"
        );
        require(msg.value > processingFee, "V:msgValue");

        IBridge.Message memory message;
        message.destChainId = destChainId;
        message.owner = msg.sender;
        message.to = to;
        message.gasLimit = gasLimit;
        message.processingFee = processingFee;
        message.depositValue = msg.value - processingFee;
        message.refundAddress = refundAddress;
        message.memo = memo;

        // prevent future PRs from changing the callValue when it must be zero
        require(message.callValue == 0, "V:callValue");

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
     * @param destChainId @custom:see IBridge.Message
     * @param to @custom:see IBridge.Message
     * @param token The address of the token to be sent.
     * @param amount The amount of token to be transferred.
     * @param gasLimit @custom:see IBridge.Message
     * @param processingFee @custom:see IBridge.Message
     * @param refundAddress @custom:see IBridge.Message
     * @param memo @custom:see IBridge.Message
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
        require(
            to != address(0) &&
                to != resolve(destChainId, "token_vault", false),
            "V:to"
        );
        require(token != address(0), "V:token");
        require(amount > 0, "V:amount");

        CanonicalERC20 memory canonicalToken;
        uint256 _amount;

        // is a bridged token, meaning, it does not live on this chain
        if (isBridgedToken[token]) {
            BridgedERC20(token).bridgeBurnFrom(msg.sender, amount);
            canonicalToken = bridgedToCanonical[token];
            require(canonicalToken.addr != address(0), "V:canonicalToken");
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

        // record the deposit for this message
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
     * source chain.
     * @param proof The proof from the destination chain to show the message
     * has failed.
     */
    function releaseERC20(
        IBridge.Message calldata message,
        bytes calldata proof
    ) external nonReentrant {
        require(message.owner != address(0), "B:owner");
        require(message.srcChainId == block.chainid, "B:srcChainId");

        IBridge bridge = IBridge(resolve("bridge", false));
        bytes32 msgHash = bridge.hashMessage(message);

        address token = messageDeposits[msgHash].token;
        uint256 amount = messageDeposits[msgHash].amount;
        require(token != address(0), "B:ERC20Released");
        require(
            bridge.isMessageFailed(msgHash, message.destChainId, proof),
            "V:notFailed"
        );

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
     * invoking a message call. See sendERC20, which sets the data to invoke
     * this function.
     * @param canonicalToken The canonical ERC20 token which may or may not
     * live on this chain. If not, a BridgedERC20 contract will be
     * deployed.
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
        require(
            ctx.sender == resolve(ctx.srcChainId, "token_vault", false),
            "V:sender"
        );

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

    /**
     * @dev Deploys a new BridgedERC20 contract and initializes it. This must be
     * called before the first time a bridged token is sent to this chain.
     */
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
