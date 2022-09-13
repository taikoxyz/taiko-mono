// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";

import "../common/EssentialContract.sol";
import "../L1/TkoToken.sol";
import "./BridgedERC20.sol";
import "./IBridge.sol";

/// @author dantaik <dan@taiko.xyz>
interface IERC20Vault {
    /**
     * @notice Transfers Ether to this vault and sends a message to the
     *         destination chain so the user can receive Ether.
     * @dev Ether are held by Bridges, not ERC20Vaults.
     * @param destChainId The destination chain ID where the `to` address lives.
     * @param to The destination address.
     * @param amount The amount of token to be transferred.
     * @param maxProcessingFee @custom:see Bridge
     */
    function sendEther(
        uint256 destChainId,
        address to,
        uint256 amount,
        uint256 maxProcessingFee
    ) external payable;

    /**
     * @notice Transfers ERC20 tokens to this vault and sends a message to the
     *         destination chain so the user can receive the same amount of tokens
     *         by invoking the message call.
     * @param token The address of the token to be sent.
     * @param destChainId The destination chain ID where the `to` address lives.
     * @param to The destination address.
     * @param refundAddress The fee refund address. If this address is address(0), extra
     *        fees will be refunded back to the `to` address.
     * @param amount The amount of token to be transferred.
     * @param maxProcessingFee @custom:see Bridge
     * @param gasLimit @custom:see Bridge
     * @param gasPrice @custom:see Bridge
     */
    function sendERC20(
        address token,
        uint256 destChainId,
        address to,
        address refundAddress,
        uint256 amount,
        uint256 maxProcessingFee,
        uint256 gasLimit,
        uint256 gasPrice
    ) external payable;
}

/**
 *  @dev This vault holds all ERC20 tokens (but not Ether) that users have deposited.
 *       It also manages the mapping between cannonical ERC20 tokens and their bridged tokens.
 */
contract ERC20Vault is EssentialContract, IERC20Vault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /*********************
     * Structs           *
     *********************/

    struct CannonicalERC20 {
        uint256 chainId;
        address addr;
        uint8 decimals;
        string symbol;
        string name;
    }

    /*********************
     * State Variables   *
     *********************/

    // Tracks if a token on the current chain is a cannoical token or a bridged token.
    mapping(address => bool) public isBridgedToken;

    // Mappings from bridged tokens to their cannonical tokens.
    mapping(address => CannonicalERC20) public bridgedToCanonical;

    // Mappings from canonical tokens to their bridged tokens.
    mapping(uint256 => mapping(address => address)) public canonicalToBridged;

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

    event ERC20Sent(
        address indexed from,
        address indexed to,
        CannonicalERC20 canonicalToken,
        uint256 amount,
        uint256 height,
        bytes32 signal,
        bytes32 messageHash,
        Message message
    );

    event EtherSent(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 height,
        bytes32 signal,
        bytes32 messageHash,
        Message message
    );

    event ERC20Received(
        address indexed from,
        address indexed to,
        address token,
        uint256 amount
    );

    /*********************
     * External Functions*
     *********************/

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    function sendEther(
        uint256 destChainId,
        address to,
        uint256 amount,
        uint256 maxProcessingFee
    ) external payable nonReentrant {
        require(destChainId != chainId(), "V:invalid destChainId");
        require(to != address(0), "V:zero to");

        address sender = _msgSender();

        Message memory message;
        message.destChainId = destChainId;
        message.owner = sender;
        message.to = to;
        message.depositValue = amount;
        message.maxProcessingFee = maxProcessingFee;

        // Ether are held by Bridges, not ERC20Vaults
        (uint256 height, bytes32 signal, bytes32 messageHash) = IBridge(
            resolve("bridge")
        ).sendMessage{value: msg.value}(
            sender, // refund unspent ether to msg sender
            message
        );

        emit EtherSent(
            sender,
            to,
            amount,
            height,
            signal,
            messageHash,
            message
        );
    }

    /// @inheritdoc IERC20Vault
    function sendERC20(
        address token,
        uint256 destChainId,
        address to,
        address refundAddress,
        uint256 amount,
        uint256 maxProcessingFee,
        uint256 gasLimit,
        uint256 gasPrice
    ) external payable nonReentrant {
        require(destChainId != chainId(), "V:invalid destChainId");
        require(to != address(0), "V:zero to");
        require(token != address(0), "V:zero token");

        CannonicalERC20 memory canonicalToken;
        uint256 _amount;
        address sender = _msgSender();

        if (isBridgedToken[token]) {
            BridgedERC20(payable(token)).bridgeBurnFrom(sender, amount);
            canonicalToken = bridgedToCanonical[token];
            _amount = amount;
        } else {
            // The canonical token lives on this chain
            ERC20Upgradeable t = ERC20Upgradeable(token);
            canonicalToken = CannonicalERC20({
                chainId: chainId(),
                addr: token,
                decimals: t.decimals(),
                symbol: t.symbol(),
                name: t.name()
            });
            _amount = _transferFrom(sender, token, amount);
        }

        Message memory message;
        message.destChainId = destChainId;
        message.owner = sender;
        message.to = _getRemoteERC20Vault(destChainId);
        message.refundAddress = refundAddress;
        message.maxProcessingFee = maxProcessingFee;
        message.gasLimit = gasLimit;
        message.gasPrice = gasPrice;
        message.data = abi.encodeWithSelector(
            ERC20Vault.receiveERC20.selector,
            canonicalToken,
            message.owner,
            to,
            _amount
        );

        (uint256 height, bytes32 signal, bytes32 messageHash) = IBridge(
            resolve("bridge")
        ).sendMessage{value: msg.value}(
            sender, // refund unspent ether to msg sender
            message
        );

        emit ERC20Sent(
            sender,
            to,
            canonicalToken,
            _amount,
            height,
            signal,
            messageHash,
            message
        );
    }

    /**
     * @dev This function can only be called by the bridge contract while invoking
     *      a message call.
     * @param canonicalToken The cannonical ERC20 token which may or may not live
     *        on this chain. If not, a BridgedERC20 contract will be deployed.
     * @param from The source address.
     * @param to The destination address.
     * @param amount The amount of tokens to be sent. 0 is a valid value.
     */
    function receiveERC20(
        CannonicalERC20 calldata canonicalToken,
        address from,
        address to,
        uint256 amount
    ) external nonReentrant onlyFromNamed("bridge") {
        IBridge.Context memory ctx = IBridge(_msgSender()).context();

        require(ctx.destChainId == chainId(), "V:invalid chain id");
        require(
            ctx.xchainSender == _getRemoteERC20Vault(ctx.srcChainId),
            "V:invalid sender"
        );

        address token;
        if (canonicalToken.chainId == chainId()) {
            require(
                isBridgedToken[canonicalToken.addr] == false,
                "V:invalid token"
            );
            token = canonicalToken.addr;
            if (token == resolve("tko")) {
                // Special handling for Tai token: we do not send TAI from
                // this vault to the user, instead, we mint new TAI to him.
                TkoToken(token).mint(to, amount);
            } else {
                IERC20Upgradeable(token).safeTransfer(to, amount);
            }
        } else {
            token = _getOrDeployBridgedToken(canonicalToken);
            BridgedERC20(payable(token)).bridgeMintTo(to, amount);
        }

        emit ERC20Received(from, to, token, amount);
    }

    function chainId() internal view returns (uint256 _chainId) {
        assembly {
            _chainId := chainid()
        }
    }

    /*********************
     * Private Functions *
     *********************/

    function _getOrDeployBridgedToken(CannonicalERC20 calldata canonicalToken)
        private
        returns (address)
    {
        address token = canonicalToBridged[canonicalToken.chainId][
            canonicalToken.addr
        ];

        return
            token != address(0) ? token : _deployBridgedToken(canonicalToken);
    }

    function _deployBridgedToken(CannonicalERC20 calldata canonicalToken)
        private
        returns (address bridgedToken)
    {
        bytes32 salt = keccak256(
            abi.encodePacked(canonicalToken.chainId, canonicalToken.addr)
        );
        bridgedToken = Create2Upgradeable.deploy(
            0, // amount of Ether to send
            salt,
            type(BridgedERC20).creationCode
        );

        BridgedERC20(payable(bridgedToken)).init(
            address(_addressManager),
            canonicalToken.addr,
            canonicalToken.chainId,
            canonicalToken.decimals,
            canonicalToken.symbol,
            string(
                abi.encodePacked(
                    canonicalToken.name,
                    "(bridged",
                    hex"F09F8C88", // 🌈
                    canonicalToken.chainId,
                    ")"
                )
            )
        );

        isBridgedToken[bridgedToken] = true;

        bridgedToCanonical[bridgedToken] = canonicalToken;

        canonicalToBridged[canonicalToken.chainId][
            canonicalToken.addr
        ] = bridgedToken;

        emit BridgedERC20Deployed(
            canonicalToken.chainId,
            canonicalToken.addr,
            bridgedToken,
            canonicalToken.symbol,
            canonicalToken.name,
            canonicalToken.decimals
        );
    }

    function _transferFrom(
        address from,
        address token,
        uint256 amount
    )
        private
        returns (
            uint256 /*_amount*/
        )
    {
        if (token == resolve("tko")) {
            // Special handling for Tai token: we do not send TAI to
            // this vault, instead, we burn the user's TAI. This is because
            // on L2, we are minting new tokens to validators and DAO.
            TkoToken(token).burn(from, amount);
            return amount;
        } else {
            IERC20Upgradeable t = IERC20Upgradeable(token);
            uint256 _balance = t.balanceOf(address(this));
            t.safeTransferFrom(from, address(this), amount);
            return t.balanceOf(address(this)) - _balance;
        }
    }

    function _getRemoteERC20Vault(uint256 _chainId)
        private
        view
        returns (address payable)
    {
        return resolve(string(abi.encodePacked(_chainId, ".erc20_vault")));
    }
}
