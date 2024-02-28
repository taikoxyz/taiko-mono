// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../common/EssentialContract.sol";
import "../bridge/IBridge.sol";

/// @title CrossChainOwned
/// @custom:security-contact security@taiko.xyz
/// @notice This contract's owner can be a local address or one that lives on another chain and uses
/// signals for transaction approval.
/// @dev Notice that when sending the message on the owner chain, the gas limit of the message must
/// not be zero, so on this chain, some EOA can help execute this transaction.
abstract contract CrossChainOwned is EssentialContract, IMessageInvocable {
    uint64 public ownerChainId; // slot 1
    uint64 public nextTxId;
    uint256[49] private __gap;

    event TransactionExecuted(uint64 indexed txId, bytes4 indexed selector);

    error XCO_INVALID_OWNER_CHAINID();
    error XCO_INVALID_TX_ID();
    error XCO_PERMISSION_DENIED();
    error XCO_TX_REVERTED();

    function onMessageInvocation(bytes calldata data)
        external
        payable
        whenNotPaused
        onlyFromNamed("bridge")
    {
        (uint64 txId, bytes memory txdata) = abi.decode(data, (uint64, bytes));
        if (txId != nextTxId) revert XCO_INVALID_TX_ID();

        IBridge.Context memory ctx = IBridge(msg.sender).context();
        if (ctx.srcChainId != ownerChainId || ctx.from != owner()) {
            revert XCO_PERMISSION_DENIED();
        }

        (bool success,) = address(this).call(txdata);
        if (!success) revert XCO_TX_REVERTED();

        emit TransactionExecuted(nextTxId++, bytes4(txdata));
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _ownerChainId The owner's deployment chain ID.
    // solhint-disable-next-line func-name-mixedcase
    function __CrossChainOwned_init(
        address _owner,
        address _addressManager,
        uint64 _ownerChainId
    )
        internal
        virtual
        onlyInitializing
    {
        __Essential_init(_owner, _addressManager);
        if (_ownerChainId == 0 || _ownerChainId == block.chainid) {
            revert XCO_INVALID_OWNER_CHAINID();
        }
        ownerChainId = _ownerChainId;
    }

    function _checkOwner() internal view virtual override {
        if (msg.sender != owner() && msg.sender != address(this)) {
            revert XCO_PERMISSION_DENIED();
        }
    }
}
