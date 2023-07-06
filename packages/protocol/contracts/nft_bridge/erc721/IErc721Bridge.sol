// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/**
 * Bridge interface for NFT contracts.
 * @dev Ether is held by Bridges on L1 and by the EtherVault on L2,
 * not TokenVaults.
 */
interface IErc721Bridge {
    struct Message {
        // Message ID.
        uint256 id;
        // Message sender address (auto filled).
        address sender;
        // Source chain ID (auto filled).
        uint256 srcChainId;
        // Destination chain ID where the `to` address lives (auto filled).
        uint256 destChainId;
        // Owner address of the bridged asset.
        address owner;
        // Destination owner address.
        address to;
        // Alternate address to send any refund. If blank, defaults to owner.
        address refundAddress;
        // Deposited token contract address (!It is always the deposited AKA original address)
        address tokenContract;
        // Token Ids - multiple per given contract can be birdged
        // For an ERC1155 the only difference is that it can have
        // multiple amounts/tokenId
        uint256[] tokenIds;
        // Processing fee for the relayer. Zero if owner will process themself.
        uint256 processingFee;
        // gasLimit to invoke on the destination chain
        uint256 gasLimit;
        // Token symbol
        string tokenSymbol;
        // Token name
        string tokenName;
        // URIs - so that it shows up as in parent chain.
        string[] tokenURIs;
    }

    struct Context {
        bytes32 msgHash;
        address sender;
        uint256 srcChainId;
    }

    event SignalSentErc721(address sender, bytes32 msgHash);
    event MessageSentErc721(bytes32 indexed msgHash, Message message);
    event TokenReleasedErc721(bytes32 indexed msgHash, address to, address token, uint256 tokenId);

    /// Sends a message to the destination chain and takes custody
    /// of the token(s) required in this contract.
    function sendMessageErc721(Message memory message)
        external
        payable
        returns (bytes32 msgHash);

    // Release token(s) with a proof that the message processing on the destination
    // chain has been failed.
    function releaseTokenErc721(
        IErc721Bridge.Message calldata message,
        bytes calldata proof
    )
        external;

    /// Checks if a msgHash has been stored on the bridge contract by the
    /// current address.
    function isMessageSentErc721(bytes32 msgHash) external view returns (bool);

    /// Checks if a msgHash has been received on the destination chain and
    /// sent by the src chain.
    function isMessageReceivedErc721(
        bytes32 msgHash,
        uint256 srcChainId,
        bytes calldata proof
    )
        external
        view
        returns (bool);

    /// Checks if a msgHash has been failed on the destination chain.
    function isMessageFailedErc721(
        bytes32 msgHash,
        uint256 destChainId,
        bytes calldata proof
    )
        external
        view
        returns (bool);

    /// Returns the bridge state context.
    function context() external view returns (Context memory context);

    function hashMessage(IErc721Bridge.Message calldata message)
        external
        pure
        returns (bytes32);
}
