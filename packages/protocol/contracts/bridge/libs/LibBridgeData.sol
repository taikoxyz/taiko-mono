// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/AddressResolver.sol";
import "../../libs/LibAddress.sol";
import "../../libs/LibMath.sol";
import "../IBridge.sol";

/**
 * Stores message data for the bridge.
 *
 * @author dantaik <dan@taiko.xyz>
 */
library LibBridgeData {
    struct State {
        uint256 nextMessageId;
        IBridge.Context ctx; // 3 slots
        uint256[46] __gap;
    }

    bytes32 internal constant MSG_HASH_PLACEHOLDER = bytes32(uint256(1));
    uint256 internal constant CHAINID_PLACEHOLDER = type(uint256).max;
    address internal constant SRC_CHAIN_SENDER_PLACEHOLDER =
        0x0000000000000000000000000000000000000001;

    // Note: These events must match the ones defined in Bridge.sol.
    event MessageSent(bytes32 indexed signal, IBridge.Message message);

    event DestChainEnabled(uint256 indexed chainId, bool enabled);

    /**
     * @dev Hashes messages and returns the hash signed with
     * "TAIKO_BRIDGE_MESSAGE" for verification.
     */
    function hashMessage(
        IBridge.Message memory message
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode("TAIKO_BRIDGE_MESSAGE", message));
    }
}
