// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "../../shared/common/EssentialContract.sol";

contract ForkManager is EssentialContract {
    // This is the keccak-256 hash of "based.forkmanager.old" subtracted by 1
    bytes32 private constant _PREV_IMPLEMENTATION_SLOT =
        0x6b4f54a58715b3dcd5173ef4b99332e6aba827ccfdb969f6e4217888b1b9b8dc;

    event ForkAdded(address indexed oldFork, address indexed newFork);

    error NotContract();
    error SameAsOld();

    function addFork(address newFork) external {
        address oldFork = StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
        require(oldFork != newFork, SameAsOld());
        require(Address.isContract(newFork), NotContract());

        StorageSlot.getAddressSlot(_PREV_IMPLEMENTATION_SLOT).value = oldFork;
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newFork;

        emit ForkAdded(oldFork, newFork);
    }

    fallback() external payable virtual {
        _fallback();
    }

    receive() external payable virtual {
        _fallback();
    }

    function _fallback() internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Load the implementation address (defaults to new implementation)
            let forkImpl := sload(_IMPLEMENTATION_SLOT)

            // ERC165 interface ID for ERC165 itself
            mstore(0x0, 0x01ffc9a7)

            // Load first 4 bytes of calldata (selector)
            mstore(0x4, calldataload(0))

            // Call supportsInterface on new implementation
            let success := staticcall(gas(), forkImpl, 0x0, 0x24, 0x0, 0x20)

            // Switch to old implementation if ERC165 check failed
            if iszero(and(success, eq(mload(0x0), 1))) {
                forkImpl := sload(_PREV_IMPLEMENTATION_SLOT)
            }

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), forkImpl, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
