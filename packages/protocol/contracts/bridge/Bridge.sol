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
import "./libs/LibBridgeRetry.sol";
import "./libs/LibBridgeSend.sol";
import "./libs/LibBridgeSignal.sol";
import "./libs/LibBridgeStatus.sol";

/**
 * Bridge contract which is deployed on both L1 and L2. Mostly a thin wrapper
 * which calls the library implementations. See _IBridge_ for more details.
 *
 * @author dantaik <dan@taiko.xyz>
 * @dev The code hash for the same address on L1 and L2 may be different.
 */
contract Bridge is EssentialContract, IBridge {
    using LibBridgeData for Message;

    /*********************
     * State Variables   *
     *********************/

    LibBridgeData.State private state; // 50 slots reserved
    uint256[50] private __gap;

    /*********************
     * Events            *
     *********************/

    event MessageStatusChanged(
        bytes32 indexed signal,
        LibBridgeStatus.MessageStatus status
    );

    event DestChainEnabled(uint256 indexed chainId, bool enabled);

    /*********************
     * External Functions*
     *********************/

    /// Allow Bridge to receive ETH from EtherVault.
    receive() external payable {}

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function sendMessage(
        Message calldata message
    ) external payable nonReentrant returns (bytes32 signal) {
        return
            LibBridgeSend.sendMessage({
                state: state,
                resolver: AddressResolver(this),
                message: message
            });
    }

    function sendSignal(bytes32 signal) external override {
        LibBridgeSignal.sendSignal(msg.sender, signal);
        emit SignalSent(msg.sender, signal);
    }

    function processMessage(
        Message calldata message,
        bytes calldata proof
    ) external nonReentrant {
        return
            LibBridgeProcess.processMessage({
                state: state,
                resolver: AddressResolver(this),
                message: message,
                proof: proof
            });
    }

    function retryMessage(
        Message calldata message,
        bool isLastAttempt
    ) external nonReentrant {
        return
            LibBridgeRetry.retryMessage({
                state: state,
                resolver: AddressResolver(this),
                message: message,
                isLastAttempt: isLastAttempt
            });
    }

    /*********************
     * Public Functions  *
     *********************/

    function isMessageSent(bytes32 signal) public view virtual returns (bool) {
        return LibBridgeSignal.isSignalSent(address(this), signal);
    }

    function isMessageReceived(
        bytes32 signal,
        uint256 srcChainId,
        bytes calldata proof
    ) public view virtual override returns (bool) {
        address srcBridge = resolve(srcChainId, "bridge");
        return
            LibBridgeSignal.isSignalReceived({
                resolver: AddressResolver(this),
                srcBridge: srcBridge,
                sender: srcBridge,
                signal: signal,
                proof: proof
            });
    }

    function isSignalSent(
        address sender,
        bytes32 signal
    ) public view virtual override returns (bool) {
        return LibBridgeSignal.isSignalSent(sender, signal);
    }

    function isSignalReceived(
        bytes32 signal,
        uint256 srcChainId,
        address sender,
        bytes calldata proof
    ) public view virtual override returns (bool) {
        address srcBridge = resolve(srcChainId, "bridge");
        return
            LibBridgeSignal.isSignalReceived({
                resolver: AddressResolver(this),
                srcBridge: srcBridge,
                sender: sender,
                signal: signal,
                proof: proof
            });
    }

    function getMessageStatus(
        bytes32 signal
    ) public view virtual returns (LibBridgeStatus.MessageStatus) {
        return LibBridgeStatus.getMessageStatus(signal);
    }

    function context() public view returns (Context memory) {
        return state.ctx;
    }

    function isDestChainEnabled(uint256 _chainId) public view returns (bool) {
        return
            LibBridgeSend.isDestChainEnabled(AddressResolver(this), _chainId);
    }

    function getMessageStatusSlot(
        bytes32 signal
    ) public pure returns (bytes32) {
        return LibBridgeStatus.getMessageStatusSlot(signal);
    }
}
