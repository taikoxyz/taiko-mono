// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity 0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "../common/EssentialContract.sol";
import "../bridge/IBridge.sol";

/// @title CrossChainOwned
/// @notice This contract's owner lives on another chain who uses signal for transaction approval.
abstract contract CrossChainOwned is EssentialContract {
    uint64 public ownerChainId; // slot 1
    uint64 public nextTxId;
    uint256[49] private __gap;

    event TransactionExecuted(uint64 indexed txId);

    error XCO_INVALID_TX_ID();
    error XCO_INVALID_OWNER_CHAINID();
    error XCO_PERMISSION_DENIED();
    error XCO_TX_REVERTED();

    function executeApprovedTransaction(uint64 txId, bytes calldata txdata) external {
        if (txId != nextTxId) revert XCO_INVALID_TX_ID();

        if (msg.sender != resolve("bridge", false)) revert XCO_PERMISSION_DENIED();

        IBridge.Context memory ctx = IBridge(msg.sender).context();
        if (ctx.srcChainId != ownerChainId || ctx.from != owner()) revert XCO_PERMISSION_DENIED();

        (bool success,) = address(this).call(txdata);
        if (!success) revert XCO_TX_REVERTED();

        emit TransactionExecuted(nextTxId++);
    }

    /// @notice Initializes the contract.
    /// @param _addressManager The address of the address manager.
    /// @param _ownerChainId The owner's deployment chain ID.
    // solhint-disable-next-line func-name-mixedcase
    function __CrossChainOwned_init(
        address _addressManager,
        uint64 _ownerChainId
    )
        internal
        virtual
    {
        __Essential_init(_addressManager);

        if (_ownerChainId == 0 || _ownerChainId == block.chainid) {
            revert XCO_INVALID_OWNER_CHAINID();
        }
        ownerChainId = _ownerChainId;
    }

    function _checkOwner() internal view virtual override {
        if (msg.sender != address(this)) revert XCO_PERMISSION_DENIED();
    }
}
