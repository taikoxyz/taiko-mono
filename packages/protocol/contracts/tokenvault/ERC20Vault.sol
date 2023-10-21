// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { BridgedERC20, ProxiedBridgedERC20 } from "./BridgedERC20.sol";
import { Create2Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import {
    ERC20Upgradeable,
    IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { IERC165Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import { IRecallableMessageSender, IBridge } from "../bridge/IBridge.sol";
import { IMintableERC20 } from "../common/IMintableERC20.sol";
import { LibAddress } from "../libs/LibAddress.sol";
import { LibVaultUtils } from "./libs/LibVaultUtils.sol";
import { Proxied } from "../common/Proxied.sol";
import { SafeERC20Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { TaikoToken } from "../L1/TaikoToken.sol";

/// @title ERC20Vault
/// @notice This vault holds all ERC20 tokens (excluding Ether) that users have
/// deposited. It also manages the mapping between canonical ERC20 tokens and
/// their bridged tokens.
contract ERC20Vault is
    EssentialContract,
    IERC165Upgradeable,
    IRecallableMessageSender
{
    using LibAddress for address;
    using SafeERC20Upgradeable for ERC20Upgradeable;

    // Structs for canonical ERC20 tokens and transfer operations
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
        uint256 fee;
        address refundTo;
        string memo;
    }

    // Tracks if a token on the current chain is a canonical or btoken.
    mapping(address => bool) public isBridgedToken;

    // Mappings from btokens to their canonical tokens.
    mapping(address => CanonicalERC20) public bridgedToCanonical;

    // Mappings from canonical tokens to their btokens. Also storing chainId for
    // tokens across other chains aside from Ethereum.
    mapping(uint256 => mapping(address => address)) public canonicalToBridged;

    uint256[47] private __gap;

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

    error VAULT_INVALID_TO();
    error VAULT_INVALID_TOKEN();
    error VAULT_INVALID_AMOUNT();
    error VAULT_INVALID_USER();
    error VAULT_INVALID_FROM();
    error VAULT_INVALID_SRC_CHAIN_ID();
    error VAULT_MESSAGE_NOT_FAILED();
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

    /// @notice Initializes the contract with the address manager.
    /// @param addressManager Address manager contract address.
    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /// @notice Transfers ERC20 tokens to this vault and sends a message to the
    /// destination chain so the user can receive the same amount of tokens by
    /// invoking the message call.
    /// @param opt Option for sending ERC20 tokens.
    function sendToken(BridgeTransferOp calldata opt)
        external
        payable
        nonReentrant
        onlyValidAddresses(opt.destChainId, "erc20_vault", opt.to, opt.token)
    {
        if (opt.amount == 0) revert VAULT_INVALID_AMOUNT();

        uint256 _amount;
        IBridge.Message memory message;

        (message.data, _amount) = _encodeDestinationCall({
            user: msg.sender,
            token: opt.token,
            amount: opt.amount,
            to: opt.to
        });

        message.destChainId = opt.destChainId;
        message.user = msg.sender;
        message.to = resolve(opt.destChainId, "erc20_vault", false);
        message.gasLimit = opt.gasLimit;
        message.value = msg.value - opt.fee;
        message.fee = opt.fee;
        message.refundTo = opt.refundTo;
        message.memo = opt.memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        emit TokenSent({
            msgHash: msgHash,
            from: message.user,
            to: opt.to,
            destChainId: opt.destChainId,
            token: opt.token,
            amount: _amount
        });
    }

    /// @notice Receive bridged ERC20 tokens and Ether.
    /// @param ctoken Canonical ERC20 data for the token being received.
    /// @param from Source address.
    /// @param to Destination address.
    /// @param amount Amount of tokens being received.
    function receiveToken(
        CanonicalERC20 calldata ctoken,
        address from,
        address to,
        uint256 amount
    )
        external
        payable
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

        to.sendEther(msg.value);

        emit TokenReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            token: token,
            amount: amount
        });
    }

    /// @notice Releases deposited ERC20 tokens back to the user on the source
    /// ERC20Vault with a proof that the message processing on the destination
    /// Bridge has failed.
    /// @param message The message that corresponds to the ERC20 deposit on the
    /// source chain.
    function onMessageRecalled(IBridge.Message calldata message)
        external
        payable
        override
        nonReentrant
        onlyFromNamed("bridge")
    {
        IBridge bridge = IBridge(resolve("bridge", false));
        bytes32 msgHash = bridge.hashMessage(message);

        (, address token,, uint256 amount) = abi.decode(
            message.data[4:], (CanonicalERC20, address, address, uint256)
        );

        if (token == address(0)) revert VAULT_INVALID_TOKEN();

        if (amount > 0) {
            if (isBridgedToken[token] || token == resolve("taiko_token", true))
            {
                IMintableERC20(token).burn(address(this), amount);
            } else {
                ERC20Upgradeable(token).safeTransfer(message.user, amount);
            }
        }

        emit TokenReleased({
            msgHash: msgHash,
            from: message.user,
            token: token,
            amount: amount
        });
    }

    /// @notice Checks if the contract supports the given interface.
    /// @param interfaceId The interface identifier.
    /// @return true if the contract supports the interface, false otherwise.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IRecallableMessageSender).interfaceId;
    }

    /// @dev Encodes sending bridged or canonical ERC20 tokens to the user.
    /// @param user The user's address.
    /// @param token The token address.
    /// @param to To address.
    /// @param amount Amount to be sent.
    /// @return msgData Encoded message data.
    /// @return _balanceChange User token balance actual change after the token
    /// transfer. This value is calculated so we do not assume token balance
    /// change is the amount of token transfered away.
    function _encodeDestinationCall(
        address user,
        address token,
        address to,
        uint256 amount
    )
        private
        returns (bytes memory msgData, uint256 _balanceChange)
    {
        CanonicalERC20 memory ctoken;

        // If it's a bridged token
        if (isBridgedToken[token]) {
            ctoken = bridgedToCanonical[token];
            assert(ctoken.addr != address(0));
            IMintableERC20(token).burn(msg.sender, amount);
            _balanceChange = amount;
        } else {
            // If it's a canonical token
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
                _balanceChange = amount;
            } else {
                uint256 _balance = t.balanceOf(address(this));
                t.transferFrom({
                    from: msg.sender,
                    to: address(this),
                    amount: amount
                });
                _balanceChange = t.balanceOf(address(this)) - _balance;
            }
        }

        msgData = abi.encodeWithSelector(
            ERC20Vault.receiveToken.selector, ctoken, user, to, _balanceChange
        );
    }

    /// @dev Retrieve or deploy a bridged ERC20 token contract.
    /// @param ctoken CanonicalERC20 data.
    /// @return btoken Address of the bridged token contract.
    function _getOrDeployBridgedToken(CanonicalERC20 calldata ctoken)
        private
        returns (address btoken)
    {
        btoken = canonicalToBridged[ctoken.chainId][ctoken.addr];

        if (btoken == address(0)) {
            btoken = _deployBridgedToken(ctoken);
        }
    }

    /// @dev Deploy a new BridgedERC20 contract and initialize it.
    /// This must be called before the first time a bridged token is sent to
    /// this chain.
    /// @param ctoken CanonicalERC20 data.
    /// @return btoken Address of the deployed bridged token contract.
    function _deployBridgedToken(CanonicalERC20 calldata ctoken)
        private
        returns (address btoken)
    {
        address bridgedToken = Create2Upgradeable.deploy({
            amount: 0, // amount of Ether to send
            salt: keccak256(abi.encode(ctoken)),
            bytecode: type(ProxiedBridgedERC20).creationCode
        });

        btoken = LibVaultUtils.deployProxy(
            address(bridgedToken),
            owner(),
            bytes.concat(
                ProxiedBridgedERC20(bridgedToken).init.selector,
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

/// @title ProxiedERC20Vault
/// @notice Proxied version of the parent contract.
contract ProxiedERC20Vault is Proxied, ERC20Vault { }
