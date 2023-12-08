// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity 0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "../common/EssentialContract.sol";
import "../signal/ISignalService.sol";

abstract contract CrossChainOwned is EssentialContract {
    mapping(bytes32 approvalHashe => bool executed) public executed; // slot 1
    uint64 public ownerChainId; // slot 2
    uint64 public nextXchainTxId;
    uint256[48] private __gap;

    event TransactionExecuted(uint64 indexed txId, bytes32 indexed approvalHash);

    error INVALID_PARAMS();
    error TX_NOT_APPROVED();
    error TX_REVERTED();

    function executeTransaction(bytes calldata txdata, bytes calldata proof) external {
        bytes32 approvalHash = _isTxApproved(txdata, proof);
        if (approvalHash == 0) revert TX_NOT_APPROVED();

        (bool success,) = address(this).call(txdata);
        if (!success) revert TX_REVERTED();
        emit TransactionExecuted(nextXchainTxId++, approvalHash);
    }

    function isTxApproved(bytes calldata txdata, bytes calldata proof) public view returns (bool) {
        return _isTxApproved(txdata, proof) != 0;
    }

    function _isTxApproved(
        bytes calldata txdata,
        bytes calldata proof
    )
        internal
        view
        returns (bytes32 approvalHash)
    {
        if (bytes4(txdata) == this.executeTransaction.selector) return 0;

        bytes32 hash = keccak256(abi.encode("CROSSCHAIN_TX", nextXchainTxId, txdata));
        if (executed[hash]) return 0;

        if (
            !ISignalService(resolve("signal_service", false)).proveSignalReceived({
                srcChainId: ownerChainId,
                app: owner(),
                signal: hash,
                proof: proof
            })
        ) return 0;

        return hash;
    }

    /// @notice Initializes the contract.
    /// @param _ownerChainId The owner's deployment chain ID.
    /// @param _addressManager The address of the address manager.
    // solhint-disable-next-line func-name-mixedcase
    function __CrossChainOwned_init(
        uint64 _ownerChainId,
        address _addressManager
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
