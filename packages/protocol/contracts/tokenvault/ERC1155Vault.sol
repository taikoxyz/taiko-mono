// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC165 } from
    "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC1155ReceiverUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
import { IERC1155Receiver } from
    "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import { ERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { Create2Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import { IBridge } from "../bridge/IBridge.sol";
import { BaseNFTVault } from "./BaseNFTVault.sol";
import { BridgedERC1155 } from "./BridgedERC1155.sol";
import { Proxied } from "../common/Proxied.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * This vault holds all ERC1155 tokens that users have deposited.
 * It also manages the mapping between canonical 1155 tokens and their bridged
 * tokens.
 */
contract ERC1155Vault is BaseNFTVault, ERC1155ReceiverUpgradeable {
    bytes4 public constant ERC1155_INTERFACE_ID = 0xd9b67a26;

    event BridgedTokenDeployed(
        uint256 indexed chainId,
        address indexed canonicalToken,
        address indexed bridgedToken
    );

    event TokenSent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 destChainId,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    event TokenReleased(
        bytes32 indexed msgHash,
        address indexed from,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    event TokenReceived(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 srcChainId,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    /**
     * Transfers ERC1155 tokens to this vault and sends a message to the
     * destination chain so the user can receive the same (bridged) tokens
     * by invoking the message call.
     *
     * @param opt Option for sending the ERC1155 token.
     */
    function sendToken(BridgeTransferOp memory opt)
        external
        payable
        nonReentrant
        onlyValidAddresses(opt.destChainId, "erc1155_vault", opt.to, opt.token)
        onlyValidAmounts(opt.amounts, opt.tokenIds, false)
    {
        if (!IERC165(opt.token).supportsInterface(ERC1155_INTERFACE_ID)) {
            revert VAULT_INTERFACE_NOT_SUPPORTED();
        }

        // We need to save them into memory - because structs containing
        // dynamic arrays will cause stack-too-deep error when passed
        uint256[] memory _amounts = opt.amounts;
        string memory _baseTokenUri = opt.baseTokenUri;
        address _token = opt.token;
        uint256[] memory _tokenIds = opt.tokenIds;
        address _to = opt.to;

        IBridge.Message memory message;
        message.destChainId = opt.destChainId;

        // TODO(dani): for function calls that take >= 3 params,
        // please use function_call({param1:v1, param2:v2,...})
        message.data = _sendToken(
            msg.sender, _to, _tokenIds, _token, _baseTokenUri, _amounts
        );

        message.owner = msg.sender;
        message.to = resolve(message.destChainId, "erc1155_vault", false);
        message.gasLimit = opt.gasLimit;
        message.processingFee = opt.processingFee;
        message.depositValue = 0;
        message.refundAddress = opt.refundAddress;
        message.memo = opt.memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        emit TokenSent({
            msgHash: msgHash,
            from: message.owner,
            to: _to,
            destChainId: message.destChainId,
            token: _token,
            tokenIds: _tokenIds,
            amounts: _amounts
        });
    }

    /**
     * @dev This function can only be called by the bridge contract while
     * invoking a message call. See sendToken, which sets the data to invoke
     * this function.
     * @param canonicalToken The canonical ERC1155 token which may or may not
     * live on this chain. If not, a BridgedERC1155 contract will be
     * deployed.
     * @param from The source address.
     * @param to The destination address.
     * @param tokenIds The tokenIds to be sent.
     * @param amounts The amounts to be sent.
     */
    function receiveToken(
        BaseNFTVault.CanonicalNFT calldata canonicalToken,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    )
        external
        nonReentrant
        onlyFromNamed("bridge")
    {
        IBridge.Context memory ctx = _checkValidContext("erc1155_vault");
        address token;

        if (canonicalToken.chainId == block.chainid) {
            token = canonicalToken.addr;
            for (uint256 i; i < tokenIds.length; i++) {
                ERC1155Upgradeable(token).safeTransferFrom(
                    address(this), to, tokenIds[i], amounts[i], ""
                );
            }
        } else {
            token = _getOrDeployBridgedToken(canonicalToken);

            for (uint256 i; i < tokenIds.length; ++i) {
                BridgedERC1155(token).mint(to, tokenIds[i], amounts[i], "");
            }
        }

        emit TokenReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            token: token,
            tokenIds: tokenIds,
            amounts: amounts
        });
    }

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

        // TODO(dani): the 'owner' variable is not used, do we need to extract
        // it
        // or we should use message.owner?
        (
            CanonicalNFT memory nft,
            address owner,
            ,
            uint256[] memory tokenIds,
            uint256[] memory amounts
        ) = decodeTokenData(message.data);

        // TODO(dani): can we have a better name for `msgHashIfValidRequest`,
        // start the method name with a verb?
        // TODO2(dani): extract the following 5 line into a new method?
        bytes32 msgHash = msgHashIfValidRequest(message, proof, nft.addr);

        if (releasedMessages[msgHash]) {
            revert VAULT_MESSAGE_RELEASED_ALREADY();
        }
        releasedMessages[msgHash] = true;

        if (isBridgedToken[nft.addr]) {
            for (uint256 i; i < tokenIds.length; i++) {
                BridgedERC1155(nft.addr).mint(
                    message.owner, tokenIds[i], amounts[i], ""
                );
            }
        } else {
            for (uint256 i; i < tokenIds.length; i++) {
                IERC1155Upgradeable(nft.addr).safeTransferFrom(
                    address(this), message.owner, tokenIds[i], amounts[i], ""
                );
            }
        }

        emit TokenReleased({
            msgHash: msgHash,
            from: message.owner,
            token: nft.addr,
            tokenIds: tokenIds,
            amounts: amounts
        });
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    )
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    )
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Decodes the data which was abi.encodeWithSelector() encoded. We need
     * this to get to know
     * to whom / which token and tokenId we shall release.
     */
    function decodeTokenData(bytes memory dataWithSelector)
        public
        pure
        returns (
            // TODO(dani): add return value name for better documentation
            // TODO(dani): use `CanonicalNFT` not `BaseNFTVault.CanonicalNFT`,
            // base class structs can be used without prefix
            BaseNFTVault.CanonicalNFT memory,
            address,
            address,
            uint256[] memory,
            uint256[] memory
        )
    {
        return abi.decode(
            _extractCalldata(dataWithSelector),
            (BaseNFTVault.CanonicalNFT, address, address, uint256[], uint256[])
        );
    }

    function _sendToken(
        address owner,
        address to,
        uint256[] memory tokenIds,
        address token,
        string memory tokenUri,
        uint256[] memory amounts
    )
        private
        returns (bytes memory)
    {
        bool isBridgedToken = isBridgedToken[token];
        // TODO(dani): bridgedToCanonical has same name as state variable, not
        // good

        CanonicalNFT memory bridgedToCanonical = bridgedToCanonical[token];

        // TODO(dani): why we have two vars for the same type here?
        BaseNFTVault.CanonicalNFT memory canonicalToken;

        // is a bridged token, meaning, it does not live on this chain
        if (isBridgedToken) {
            for (uint256 i; i < tokenIds.length; i++) {
                // TODO(dani): I don't think we need to check balance, as long
                // as burn is successful, balance should be OK.
                if (
                    BridgedERC1155(token).balanceOf(owner, tokenIds[i])
                        < amounts[i]
                ) {
                    // TODO(Dani): invalid Owner?
                    revert VAULT_INVALID_OWNER();
                }

                BridgedERC1155(token).burn(owner, tokenIds[i], amounts[i]);
            }
            canonicalToken = bridgedToCanonical;

            // TODO(dani): We should not check this, it should be guaranteed at
            // this point
            // that the canonical token address cannot be zero. If not, we
            // should
            // check non-zero very early!!!
            if (canonicalToken.addr == address(0)) {
                revert VAULT_CANONICAL_TOKEN_NOT_FOUND();
            }
        } else {
            // is a canonical token, meaning, it lives on this chain
            ERC1155Upgradeable t = ERC1155Upgradeable(token);

            canonicalToken = BaseNFTVault.CanonicalNFT({
                chainId: block.chainid,
                addr: token,
                symbol: "", // TODO(dani): query symbol, and name
                name: "",
                uri: tokenUri
            });

            for (uint256 i; i < tokenIds.length; i++) {
                // No need to check balance
                if (
                    BridgedERC1155(token).balanceOf(owner, tokenIds[i])
                        < amounts[i]
                ) {
                    revert VAULT_INVALID_OWNER();
                }
                t.safeTransferFrom(
                    msg.sender, address(this), tokenIds[i], amounts[i], ""
                );
            }
        }

        return abi.encodeWithSelector(
            ERC1155Vault.receiveToken.selector,
            canonicalToken,
            owner,
            to,
            tokenIds,
            amounts
        );
    }

    function _getOrDeployBridgedToken(
        BaseNFTVault.CanonicalNFT memory canonicalToken
    )
        private
        returns (address bridgedToken)
    {
        bridgedToken =
            canonicalToBridged[canonicalToken.chainId][canonicalToken.addr];

        if (bridgedToken == address(0)) {
            bridgedToken = _deployBridgedToken(canonicalToken);
        }
    }

    /**
     * @dev Deploys a new BridgedNFT contract and initializes it. This must be
     * called before the first time a bridged token is sent to this chain.
     */
    function _deployBridgedToken(
        BaseNFTVault.CanonicalNFT memory canonicalToken
    )
        private
        returns (address bridgedToken)
    {
        // TODO(dani): use form: method_name({param1:1, param2:, ...})
        bridgedToken = Create2Upgradeable.deploy(
            0, // amount of Ether to send
            keccak256(
                bytes.concat(
                    bytes32(canonicalToken.chainId),
                    bytes32(uint256(uint160(canonicalToken.addr)))
                )
            ),
            type(BridgedERC1155).creationCode
        );

        BridgedERC1155(payable(bridgedToken)).init({
            _addressManager: address(_addressManager),
            _srcToken: canonicalToken.addr,
            _srcChainId: canonicalToken.chainId,
            _uri: canonicalToken.uri
        });

        isBridgedToken[bridgedToken] = true;
        bridgedToCanonical[bridgedToken] = canonicalToken;
        canonicalToBridged[canonicalToken.chainId][canonicalToken.addr] =
            bridgedToken;

        emit BridgedTokenDeployed({
            chainId: canonicalToken.chainId,
            canonicalToken: canonicalToken.addr,
            bridgedToken: bridgedToken
        });
    }
}

contract ProxiedERC1155Vault is Proxied, ERC1155Vault { }
