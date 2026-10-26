// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/src/Test.sol";

/// @dev Tests the alloc-only Etna genesis builder and its canonical system bytecode in a local
/// EVM. Execution-client fork activation and block-0 commitments require separate integration
/// tests.
contract EtnaGenesisTest is Test {
    /// @dev The former fee-vault treasury address; the alloc-only genesis installs nothing there.
    address private constant _VAULT = 0x1670010000000000000000000000000000010001;
    address private constant _ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    address private constant _HISTORY = 0x0000F90827F1C53a10cb7A02335B175320002935;
    address private constant _SYSTEM = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;

    function test_buildGenesis_InstallsCanonicalSystemContracts() external {
        string memory genesis = _build();
        assertEq(vm.parseJsonKeys(genesis, ".alloc").length, 2, "only the system contracts");
        assertFalse(vm.keyExistsJson(genesis, _allocKey(_VAULT)), "no vault alloc");
        assertEq(_VAULT.code.length, 0);
        assertEq(
            sha256(_ROOTS.code),
            hex"cb7bd3e115730f7d57c15cd892880ed517ff4421bf43dfc7591198868fffe31d"
        );
        assertEq(
            sha256(_HISTORY.code),
            hex"41cd74981e0201f79ebca054c4e8102a7e6faa28ce015d0048ab2250c1222c67"
        );
        assertEq(_ROOTS.balance, 0);
        assertEq(_HISTORY.balance, 0);
        assertEq(vm.getNonce(_ROOTS), 1);
        assertEq(vm.getNonce(_HISTORY), 1);
    }

    function test_systemContracts_PrivilegedWriteAndRead() external {
        _build();
        bytes32 root = bytes32(uint256(0xabc));
        vm.roll(2);
        vm.warp(100);
        vm.prank(_SYSTEM);
        (bool ok,) = _ROOTS.call(abi.encode(root));
        assertTrue(ok);
        bytes memory data;
        (ok, data) = _ROOTS.staticcall(abi.encode(uint256(100)));
        assertTrue(ok);
        assertEq(abi.decode(data, (bytes32)), root);
        (ok,) = _ROOTS.call(abi.encode(bytes32(uint256(123))));
        assertFalse(ok, "ordinary read of unavailable timestamp reverts");
        (ok, data) = _ROOTS.call(abi.encode(uint256(100)));
        assertTrue(ok, "ordinary caller can read an existing root");
        assertEq(abi.decode(data, (bytes32)), root);
        assertEq(vm.load(_ROOTS, bytes32(uint256(100))), bytes32(uint256(100)));
        assertEq(vm.load(_ROOTS, bytes32(uint256(100 + 8191))), root);
        vm.prank(_SYSTEM);
        (ok,) = _HISTORY.call(abi.encode(bytes32(uint256(456))));
        assertTrue(ok);
        (ok, data) = _HISTORY.staticcall(abi.encode(uint256(1)));
        assertTrue(ok);
        assertEq(abi.decode(data, (bytes32)), bytes32(uint256(456)));
        vm.warp(8291);
        vm.prank(_SYSTEM);
        (ok,) = _ROOTS.call(abi.encode(bytes32(uint256(789))));
        assertTrue(ok);
        (ok,) = _ROOTS.staticcall(abi.encode(uint256(100)));
        assertFalse(ok, "overwritten timestamp expires");
    }

    /// @dev Runs the builder through FFI on an empty-alloc base and installs its system contracts.
    /// @return genesis_ The generated genesis JSON.
    function _build() private returns (string memory genesis_) {
        vm.writeFile(
            _path("base"), "{\"config\":{\"chainId\":167001},\"timestamp\":\"0x0\",\"alloc\":{}}"
        );
        string[] memory command = new string[](6);
        command[0] = "python3";
        command[1] = "script/layer2/build_etna_genesis.py";
        command[2] = "--base";
        command[3] = _path("base");
        command[4] = "--output";
        command[5] = _path("genesis");
        vm.ffi(command);
        genesis_ = vm.readFile(_path("genesis"));
        _install(genesis_, _ROOTS);
        _install(genesis_, _HISTORY);
    }

    /// @dev Returns a per-test file path; Foundry runs tests concurrently.
    /// @param _kind The file kind, used as a suffix.
    /// @return The path within Foundry's permitted deployments directory.
    function _path(string memory _kind) private pure returns (string memory) {
        return string.concat("deployments/etna-test-", vm.toString(msg.sig), "-", _kind, ".json");
    }

    /// @dev Returns the JSON path of an account's alloc entry.
    /// @param _address The account.
    /// @return The JSON path, keyed by the lowercase address.
    function _allocKey(address _address) private pure returns (string memory) {
        return string.concat(".alloc.", vm.toLowercase(vm.toString(_address)));
    }

    /// @dev Installs one alloc account's code, balance and nonce in the local EVM.
    /// @param _json The genesis JSON.
    /// @param _address The account to install.
    function _install(string memory _json, address _address) private {
        string memory key = string.concat(_allocKey(_address), ".");
        vm.etch(_address, vm.parseJsonBytes(_json, string.concat(key, "code")));
        vm.deal(_address, vm.parseJsonUint(_json, string.concat(key, "balance")));
        vm.setNonce(_address, uint64(vm.parseJsonUint(_json, string.concat(key, "nonce"))));
    }
}
