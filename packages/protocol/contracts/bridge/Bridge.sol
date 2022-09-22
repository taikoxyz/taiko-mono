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
    using LibBridgeData for Message;
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

    event MessageSent(bytes32 indexed mhash, IBridge.Message message);

    event MessageStatusChanged(
        bytes32 indexed mhash,
        IBridge.MessageStatus status
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

    function sendMessage(Message calldata message)
        external
        payable
        nonReentrant
        returns (bytes32 mhash)
    {
<<<<<<< HEAD
        return state.sendMessage(message);
=======
        return state.sendMessage(message); //LibBridgeSend
>>>>>>> 100d8fbd286476792a5f01f2548cd03cc747440b
    }

    function processMessage(Message calldata message, bytes calldata proof)
        external
        nonReentrant
    {
<<<<<<< HEAD
=======
        //LibBridgeProcess
>>>>>>> 100d8fbd286476792a5f01f2548cd03cc747440b
        return state.processMessage(AddressResolver(this), message, proof);
    }

    function retryMessage(Message calldata message, bool lastAttempt)
        external
        nonReentrant
    {
<<<<<<< HEAD
        return state.retryMessage(message, lastAttempt);
=======
        return state.retryMessage(message, lastAttempt); //LibBridgeRetry
>>>>>>> 100d8fbd286476792a5f01f2548cd03cc747440b
    }

    function enableDestChain(uint256 _chainId, bool enabled)
        external
        nonReentrant
    {
        state.enableDestChain(_chainId, enabled); //LibBridgeSend
    }

    /*********************
     * Public Functions  *
     *********************/

    function isMessageSent(bytes32 mhash) public view virtual returns (bool) {
<<<<<<< HEAD
=======
        // * Why is this LibBridgeRead and not state or AddressResolver ?
>>>>>>> 100d8fbd286476792a5f01f2548cd03cc747440b
        return LibBridgeRead.isMessageSent(mhash);
    }

    function isMessageReceived(
        bytes32 mhash,
        uint256 srcChainId,
        bytes calldata proof
    ) public view virtual returns (bool) {
        return
<<<<<<< HEAD
=======
            // LibBridgeRead
>>>>>>> 100d8fbd286476792a5f01f2548cd03cc747440b
            AddressResolver(this).isMessageReceived(mhash, srcChainId, proof);
    }

    function getMessageStatus(bytes32 mhash)
        public
        view
        virtual
        returns (MessageStatus)
    {
        return state.messageStatus[mhash];
    }

    function context() public view returns (Context memory) {
        return state.ctx;
    }

    function isDestChainEnabled(uint256 _chainId) public view returns (bool) {
        return state.isDestChainEnabled(_chainId); //LibBridgeRead
    }
}
