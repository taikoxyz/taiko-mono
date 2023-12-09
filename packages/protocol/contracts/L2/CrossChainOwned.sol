// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity 0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "../common/EssentialContract.sol";
import "../signal/ISignalService.sol";

/// @title CrossChainOwned
/// @notice This contract's owner lives on another chain who uses signal for transaction approval.
abstract contract CrossChainOwned is EssentialContract {
    uint64 public ownerChainId; // slot 1
    uint64 public nextXchainTxId;
    uint256[49] private __gap;

    event TransactionExecuted(uint64 indexed txId, bytes32 indexed approvalHash);

    error INVALID_PARAMS();
    error TX_NOT_APPROVED();
    error TX_REVERTED();
    error NOT_CALLABLE();

    function executeApprovedTransaction(bytes calldata txdata, bytes calldata proof) external {
        bytes32 approvalHash = _isTransactionApproved(txdata, proof);
        if (approvalHash == 0) revert TX_NOT_APPROVED();

        (bool success,) = address(this).call(txdata);
        if (!success) revert TX_REVERTED();
        emit TransactionExecuted(nextXchainTxId++, approvalHash);
    }

    function isTransactionApproved(
        bytes calldata txdata,
        bytes calldata proof
    )
        public
        view
        returns (bool)
    {
        return _isTransactionApproved(txdata, proof) != 0;
    }

    function _isTransactionApproved(
        bytes calldata txdata,
        bytes calldata proof
    )
        internal
        view
        returns (bytes32 approvalHash)
    {
        if (bytes4(txdata) == this.executeApprovedTransaction.selector) return 0;

        bytes32 hash = keccak256(abi.encode("CROSS_CHAIN_TX", nextXchainTxId, txdata));

        if (_isSignalReceived(hash, proof)) return hash;
        else return 0;
    }

    function _isSignalReceived(
        bytes32 signal,
        bytes calldata proof
    )
        internal
        view
        virtual
        returns (bool)
    {
        return ISignalService(resolve("signal_service", false)).proveSignalReceived({
            srcChainId: ownerChainId,
            app: owner(),
            signal: signal,
            proof: proof
        });
    }

    function _checkOwner() internal view virtual override {
        if (msg.sender != address(this)) revert NOT_CALLABLE();
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

        if (_ownerChainId == 0 || _ownerChainId == block.chainid) revert INVALID_PARAMS();
        ownerChainId = _ownerChainId;
        nextXchainTxId = 1;
    }
}
