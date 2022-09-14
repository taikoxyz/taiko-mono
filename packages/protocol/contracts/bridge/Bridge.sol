// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../common/EssentialContract.sol";
import "./IBridge.sol";
import "./libs/LibBridgeData.sol";
import "./libs/LibBridgeProcess.sol";
import "./libs/LibBridgeRead.sol";
import "./libs/LibBridgeRetry.sol";
import "./libs/LibBridgeSend.sol";

/// @author dantaik <dan@taiko.xyz>
/// @dev The code hash for the same address on L1 and L2 may be different.
contract Bridge is EssentialContract, IBridge {
    using LibBridgeProcess for LibBridgeData.State;
    using LibBridgeRead for AddressResolver;
    using LibBridgeRead for LibBridgeData.State;
    using LibBridgeRetry for LibBridgeData.State;
    using LibBridgeSend for LibBridgeData.State;

    /*********************
     * State Variables   *
     *********************/

    LibBridgeData.State private state; // 50 slots reserved
    uint256[50] private __gap;

    /*********************
     * Events             *
     *********************/

    // Note these events must match the one defined in Bridge.sol.
    event MessageSent(
        bytes32 indexed messageHash, // signal value
        address indexed owner,
        uint256 srcChainId,
        uint256 id,
        uint256 height, // used for compute message proofs
        bytes32 signal,
        bytes message
    );

    event MessageStatusChanged(
        bytes32 indexed messageHash, // signal value
        address indexed owner,
        uint256 srcChainId,
        uint256 id,
        IBridge.MessageStatus status,
        bool succeeded
    );

    event DestChainEnabled(uint256 indexed chainId, bool enabled);

    /*********************
     * External Functions*
     *********************/

    /// allow Bridge to receive ETH directly.
    receive() external payable {}

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function sendMessage(address refundFeeTo, Message memory message)
        external
        payable
        nonReentrant
        returns (
            uint256 height,
            bytes32 signal,
            bytes32 messageHash
        )
    {
        return state.sendMessage(_msgSender(), refundFeeTo, message);
    }

    function processMessage(Message memory message, bytes memory proof)
        external
        nonReentrant
    {
        return
            state.processMessage(
                AddressResolver(this),
                _msgSender(),
                message,
                proof
            );
    }

    function retryMessage(
        Message memory message,
        bytes memory proof,
        bool lastAttempt
    ) external nonReentrant {
        return
            state.retryMessage(
                AddressResolver(this),
                _msgSender(),
                message,
                proof,
                lastAttempt
            );
    }

    function enableDestChain(uint256 _chainId, bool enabled)
        external
        nonReentrant
    {
        state.enableDestChain(_chainId, enabled);
    }

    /*********************
     * Public Functions  *
     *********************/

    function isMessageReceived(Message memory message, bytes memory proof)
        public
        view
        virtual
        returns (bool received, bytes32 messageHash)
    {
        return AddressResolver(this).isMessageReceived(message, proof);
    }

    function getMessageStatus(uint256 srcChainId, uint256 messageId)
        public
        view
        virtual
        returns (MessageStatus)
    {
        return state.getMessageStatus(srcChainId, messageId);
    }

    function context() public view returns (Context memory) {
        return state.context();
    }

    function isDestChainEnabled(uint256 _chainId) public view returns (bool) {
        return state.isDestChainEnabled(_chainId);
    }
}
