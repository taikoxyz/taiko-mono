// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from "forge-std/src/Vm.sol";

/// @title LibRebuiltCode
/// @notice Checks that a deployed contract is exactly a reference build: the same artifact,
/// constructed with the same arguments. Proposal builders use it where a contract's immutables
/// have no getter, such as the SignalService's syncer and remote.
/// @dev The caller creates the reference in the script's local EVM with the expected constructor
/// arguments. The reference's runtime code then holds every expected immutable, except those that
/// hold the contract's own address: UUPS `__self` is `address(this)`. `rebuild` reads the
/// immutable positions from the compiled artifact's `deployedBytecode.immutableReferences` and
/// sets every one holding the reference's address to the deployed address. The result must equal
/// the deployed code byte for byte, so a different syncer, remote, pauser, flag or bytecode is
/// refused.
/// @custom:security-contact security@taiko.xyz
library LibRebuiltCode {
    /// @dev One `deployedBytecode.immutableReferences` entry; JSON keys sort alphabetically.
    struct ImmutableReference {
        uint256 length;
        uint256 start;
    }

    /// @dev The forge cheatcode address.
    Vm private constant _VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Whether `_deployed` holds `_reference`'s code as it would be had it been created at
    /// `_deployed`.
    /// @param _deployed The contract to check.
    /// @param _reference A local build from the expected artifact and constructor arguments.
    /// @return Whether the codes are equal.
    function matches(address _deployed, address _reference) internal view returns (bool) {
        return _deployed.code.length != 0
            && keccak256(rebuild(_reference, _deployed)) == _deployed.codehash;
    }

    /// @dev `_reference`'s runtime code with every immutable that holds its own address set to
    /// `_at`.
    /// @param _reference A local build from the expected artifact and constructor arguments.
    /// @param _at The address the rebuilt code is for.
    /// @return code_ The rebuilt runtime code.
    function rebuild(
        address _reference,
        address _at
    )
        internal
        view
        returns (bytes memory code_)
    {
        code_ = _reference.code;
        string memory json = _VM.readFile(_VM.getArtifactPathByDeployedCode(code_));
        string memory root = ".deployedBytecode.immutableReferences";
        // The compiler omits the entry for a contract without immutables.
        if (!_VM.keyExistsJson(json, root)) return code_;
        string[] memory ids = _VM.parseJsonKeys(json, root);
        bytes32 own = bytes32(uint256(uint160(_reference)));
        bytes32 at = bytes32(uint256(uint160(_at)));
        for (uint256 i; i < ids.length; ++i) {
            ImmutableReference[] memory refs = abi.decode(
                _VM.parseJson(json, string.concat(root, ".", ids[i])), (ImmutableReference[])
            );
            for (uint256 j; j < refs.length; ++j) {
                require(
                    refs[j].length == 32 && refs[j].start + 32 <= code_.length,
                    InvalidImmutableReference()
                );
                uint256 start = refs[j].start;
                bytes32 word;
                assembly ("memory-safe") {
                    word := mload(add(add(code_, 32), start))
                }
                if (word != own) continue;
                assembly ("memory-safe") {
                    mstore(add(add(code_, 32), start), at)
                }
            }
        }
    }

    error InvalidImmutableReference();
}
