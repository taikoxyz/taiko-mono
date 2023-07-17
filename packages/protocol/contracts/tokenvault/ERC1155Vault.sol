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
 * Some ERC1155 contracts implementing the name() and symbol()
 * functions, although they are not part of the interface
 */
interface ERC1155NameAndSymbol {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

/**
 * This vault holds all ERC1155 tokens that users have deposited.
 * It also manages the mapping between canonical tokens and their bridged
 * tokens.
 */
contract ERC1155Vault is BaseNFTVault, ERC1155ReceiverUpgradeable {
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
        if (
            !IERC165(opt.token).supportsInterface(ERC1155_INTERFACE_ID)
                || IERC165(opt.token).supportsInterface(ERC721_INTERFACE_ID)
        ) {
            revert VAULT_INTERFACE_NOT_SUPPORTED();
        }

        // We need to save them into memory - because structs containing
        // dynamic arrays will cause stack-too-deep error when passed to the
        // emited event
        uint256[] memory _amounts = opt.amounts;
        address _token = opt.token;
        uint256[] memory _tokenIds = opt.tokenIds;

        IBridge.Message memory message;
        message.destChainId = opt.destChainId;

        message.data = _sendToken(msg.sender, opt);

        message.owner = msg.sender;
        message.to = resolve(message.destChainId, "erc1155_vault", false);
        message.gasLimit = opt.gasLimit;
        message.processingFee = opt.processingFee;
        message.refundAddress = opt.refundAddress;
        message.memo = opt.memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        emit TokenSent({
            msgHash: msgHash,
            from: message.owner,
            to: opt.to,
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
     * @param ctoken The canonical ERC1155 token which may or may not
     * live on this chain. If not, a BridgedERC1155 contract will be
     * deployed.
     * @param from The source address.
     * @param to The destination address.
     * @param tokenIds The tokenIds to be sent.
     * @param amounts The amounts to be sent.
     */
    function receiveToken(
        CanonicalNFT calldata ctoken,
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

        if (ctoken.chainId == block.chainid) {
            token = ctoken.addr;
            for (uint256 i; i < tokenIds.length; i++) {
                ERC1155Upgradeable(token).safeTransferFrom(
                    address(this), to, tokenIds[i], amounts[i], ""
                );
            }
        } else {
            token = _getOrDeployBridgedToken(ctoken);

            for (uint256 i; i < tokenIds.length; ++i) {
                BridgedERC1155(token).mint(to, tokenIds[i], amounts[i]);
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

        (
            CanonicalNFT memory nft,
            ,
            ,
            uint256[] memory tokenIds,
            uint256[] memory amounts
        ) = decodeMessageData(message.data);

        bytes32 msgHash = hashAndMarkMsgReleased(message, proof, nft.addr);

        if (isBridgedToken[nft.addr]) {
            for (uint256 i; i < tokenIds.length; i++) {
                BridgedERC1155(nft.addr).mint(
                    message.owner, tokenIds[i], amounts[i]
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
     * Decodes the data which was abi.encodeWithSelector() encoded.
     * @param dataWithSelector Data encoded with abi.encodedWithSelector
     * @return nft CanonicalNFT data
     * @return owner Owner of the message
     * @return to The to address messages sent to
     * @return tokenIds The tokenIds
     * @return amounts The amount per respective ERC1155 tokenid
     */
    function decodeMessageData(bytes memory dataWithSelector)
        public
        pure
        returns (
            CanonicalNFT memory nft,
            address owner,
            address to,
            uint256[] memory tokenIds,
            uint256[] memory amounts
        )
    {
        return abi.decode(
            _extractCalldata(dataWithSelector),
            (CanonicalNFT, address, address, uint256[], uint256[])
        );
    }

    function _sendToken(
        address owner,
        BridgeTransferOp memory opt
    )
        private
        returns (bytes memory)
    {
        bool isBridgedToken = isBridgedToken[opt.token];

        CanonicalNFT memory nft = bridgedToCanonical[opt.token];

        // is a btoken, meaning, it does not live on this chain
        if (isBridgedToken) {
            for (uint256 i; i < opt.tokenIds.length; i++) {
                BridgedERC1155(opt.token).burn(
                    owner, opt.tokenIds[i], opt.amounts[i]
                );
            }
        } else {
            // is a ctoken token, meaning, it lives on this chain
            ERC1155Upgradeable t = ERC1155Upgradeable(opt.token);
            string memory name;
            try ERC1155NameAndSymbol(opt.token).name() {
                name = ERC1155NameAndSymbol(opt.token).name();
            } catch { }

            string memory symbol;
            try ERC1155NameAndSymbol(opt.token).symbol() {
                symbol = ERC1155NameAndSymbol(opt.token).symbol();
            } catch { }

            nft = CanonicalNFT({
                chainId: block.chainid,
                addr: opt.token,
                symbol: symbol,
                name: name,
                uri: opt.baseTokenUri // TODO(dani):from user? Please see my
                    // design props/questions ERC721Vault line 56.
             });

            for (uint256 i; i < opt.tokenIds.length; i++) {
                t.safeTransferFrom(
                    msg.sender,
                    address(this),
                    opt.tokenIds[i],
                    opt.amounts[i],
                    ""
                );
            }
        }

        return abi.encodeWithSelector(
            ERC1155Vault.receiveToken.selector,
            nft,
            owner,
            opt.to,
            opt.tokenIds,
            opt.amounts
        );
    }

    function _getOrDeployBridgedToken(CanonicalNFT memory ctoken)
        private
        returns (address btoken)
    {
        btoken = canonicalToBridged[ctoken.chainId][ctoken.addr];

        if (btoken == address(0)) {
            btoken = _deployBridgedToken(ctoken);
        }
    }

    /**
     * @dev Deploys a new BridgedNFT contract and initializes it. This must be
     * called before the first time a btoken is sent to this chain.
     */
    function _deployBridgedToken(CanonicalNFT memory ctoken)
        private
        returns (address btoken)
    {
        btoken = Create2Upgradeable.deploy({
            amount: 0, // amount of Ether to send
            salt: keccak256(
                bytes.concat(
                    bytes32(ctoken.chainId), bytes32(uint256(uint160(ctoken.addr)))
                )
                ),
            bytecode: type(BridgedERC1155).creationCode
        });

        BridgedERC1155(payable(btoken)).init({
            _addressManager: address(_addressManager),
            _srcToken: ctoken.addr,
            _srcChainId: ctoken.chainId,
            _name: ctoken.name,
            _symbol: ctoken.symbol,
            _uri: ctoken.uri
        });

        isBridgedToken[btoken] = true;
        bridgedToCanonical[btoken] = ctoken;
        canonicalToBridged[ctoken.chainId][ctoken.addr] = btoken;

        emit BridgedTokenDeployed({
            chainId: ctoken.chainId,
            ctoken: ctoken.addr,
            btoken: btoken,
            ctokenSymbol: ctoken.symbol,
            ctokenName: ctoken.name
        });
    }
}

contract ProxiedERC1155Vault is Proxied, ERC1155Vault { }
