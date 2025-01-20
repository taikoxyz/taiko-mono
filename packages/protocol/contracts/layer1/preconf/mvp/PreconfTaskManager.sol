// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "src/layer1/preconf/iface/IPreconfTaskManager.sol";
import "src/layer1/preconf/iface/IPreconfServiceManager.sol";
import "src/layer1/preconf/iface/IPreconfRegistry.sol";
import "src/layer1/preconf/libs/LibEIP4788.sol";
import "src/shared/libs/LibStrings.sol";

import "src/shared/common/EssentialContract.sol";
import "./IPreconfWhitelist.sol";
/// @title PreconfTaskManager
/// @custom:security-contact security@taiko.xyz

contract PreconfTaskManager is EssentialContract {
    uint256 internal constant SLOTS_IN_EPOCH = 32;

    /// @dev The block proposer is not an eligible proposer
    error SenderIsNotThePreconfer();

    uint256[50] private __gap;

    function init(address _owner, address _rollupResolver) external initializer {
        __Essential_init(_owner, _rollupResolver);

        IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false)).approve(
            resolve(LibStrings.B_TAIKO, false), type(uint256).max
        );
    }

    /**
     * @notice Proposes a new batch of Taiko L2 blocks.
     * @param batchParams A list of block parameters expected by Taiko contract
     * @param txList Txlist to be proposed
     */
    function proposeBatch(
        ITaikoInbox.BatchParams calldata batchParams,
        bytes calldata txList
    )
        external
    {
        require(
            IPreconfWhitelist(resolve("preconf_whitelist", false)).isEligibleProposer(msg.sender),
            SenderIsNotThePreconfer()
        );

        // Forward the block to Taiko's L1 contract
        ITaikoInbox(resolve(LibStrings.B_TAIKO, false)).proposeBatch(
            abi.encode(msg.sender, batchParams.coinbase, batchParams), txList
        );
    }
}
