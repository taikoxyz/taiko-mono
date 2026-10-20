// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaVaultProof } from "./L2FeeVaultTestBase.sol";
import { Test } from "forge-std/src/Test.sol";
import { ExportEtnaGenesis } from "script/layer2/ExportEtnaGenesis.s.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";
import { LibEtnaRewards } from "src/shared/libs/LibEtnaRewards.sol";

/// @dev Tests the immutable runtime and canonical system bytecode in a local EVM.
/// Execution-client fork activation and block-0 commitments require separate integration tests.
contract EtnaGenesisTest is Test {
    address private constant _VAULT = 0x1670010000000000000000000000000000010001;
    address private constant _ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    address private constant _HISTORY = 0x0000F90827F1C53a10cb7A02335B175320002935;
    address private constant _SYSTEM = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;
    address private constant _INBOX = address(0x1111);

    function test_exportRuntime_ConstructsImmutablesAndChangesWithIdentity() external {
        bytes memory runtime = _export(1, _INBOX);
        vm.etch(_VAULT, runtime);
        assertEq(L2FeeVault(_VAULT).l1ChainId(), 1);
        assertEq(L2FeeVault(_VAULT).l1Inbox(), _INBOX);
        assertEq(_export(1, _INBOX), runtime, "reproducible runtime");
        assertNotEq(keccak256(runtime), keccak256(_export(2, _INBOX)), "L1 chain changes runtime");
        assertNotEq(
            keccak256(runtime), keccak256(_export(1, address(0x2222))), "Inbox changes runtime"
        );
        bytes memory other = _export(2, address(0x2222));
        assertNotEq(keccak256(runtime), keccak256(other));
        vm.etch(_VAULT, other);
        assertEq(L2FeeVault(_VAULT).l1ChainId(), 2);
        assertEq(L2FeeVault(_VAULT).l1Inbox(), address(0x2222));
    }

    function test_buildGenesis_InstallsRuntimeAndCanonicalSystemContracts() external {
        _build(1, _INBOX);
        assertEq(_VAULT.balance, 0);
        assertEq(_ROOTS.balance, 0);
        assertEq(_HISTORY.balance, 0);
        assertEq(L2FeeVault(_VAULT).l1ChainId(), 1);
        assertEq(L2FeeVault(_VAULT).l1Inbox(), _INBOX);
        assertEq(
            sha256(_ROOTS.code),
            hex"cb7bd3e115730f7d57c15cd892880ed517ff4421bf43dfc7591198868fffe31d"
        );
        assertEq(
            sha256(_HISTORY.code),
            hex"41cd74981e0201f79ebca054c4e8102a7e6faa28ce015d0048ab2250c1222c67"
        );
        assertEq(vm.getNonce(_VAULT), 1);
        assertEq(vm.getNonce(_ROOTS), 1);
        assertEq(vm.getNonce(_HISTORY), 1);
    }

    /// @notice Verifies genuine exported vault runtime for a different L1 chain and Inbox.
    function test_buildGenesis_AcceptsGenuineExportForAnotherIdentity() external {
        _build(2, address(0x2222));
        assertEq(L2FeeVault(_VAULT).l1ChainId(), 2);
        assertEq(L2FeeVault(_VAULT).l1Inbox(), address(0x2222));
        assertEq(_VAULT.code, address(new L2FeeVault(2, address(0x2222))).code);
    }

    function test_systemContracts_PrivilegedWriteReadAndVaultClaim() external {
        _build(1, _INBOX);
        vm.chainId(167_001);
        vm.roll(2);
        vm.warp(100);
        LibEtnaRewards.Receipt memory receipt = EtnaVaultProof.receipt(0, address(0x2222), 3 ether);
        receipt.l2ChainId = 167_001;
        EtnaVaultProof.Proof memory proof = EtnaVaultProof.proof(receipt);
        vm.prank(_SYSTEM);
        (bool ok,) = _ROOTS.call(abi.encode(proof.root));
        assertTrue(ok);
        bytes memory data;
        (ok, data) = _ROOTS.staticcall(abi.encode(uint256(100)));
        assertTrue(ok);
        assertEq(abi.decode(data, (bytes32)), proof.root);
        (ok,) = _ROOTS.call(abi.encode(bytes32(uint256(123))));
        assertFalse(ok, "ordinary read of unavailable timestamp reverts");
        (ok, data) = _ROOTS.call(abi.encode(uint256(100)));
        assertTrue(ok, "ordinary caller can read an existing root");
        assertEq(abi.decode(data, (bytes32)), proof.root);
        assertEq(vm.load(_ROOTS, bytes32(uint256(100))), bytes32(uint256(100)));
        assertEq(vm.load(_ROOTS, bytes32(uint256(100 + 8191))), proof.root);
        vm.prank(_SYSTEM);
        (ok,) = _HISTORY.call(abi.encode(bytes32(uint256(456))));
        assertTrue(ok);
        (ok, data) = _HISTORY.staticcall(abi.encode(uint256(1)));
        assertTrue(ok);
        assertEq(abi.decode(data, (bytes32)), bytes32(uint256(456)));
        vm.deal(_VAULT, 3 ether);
        L2FeeVault(_VAULT).claim(receipt, 100, proof.account, proof.storageProof);
        assertEq(address(0x2222).balance, 3 ether);
        assertTrue(L2FeeVault(_VAULT).claimed(EtnaVaultProof.batchId(receipt)));
        vm.warp(8291);
        vm.prank(_SYSTEM);
        (ok,) = _ROOTS.call(abi.encode(bytes32(uint256(789))));
        assertTrue(ok);
        (ok,) = _ROOTS.staticcall(abi.encode(uint256(100)));
        assertFalse(ok, "overwritten timestamp expires");
    }

    function _export(uint256 _chainId, address _inbox) private returns (bytes memory runtime_) {
        runtime_ = new ExportEtnaGenesis().exportRuntime(_chainId, _inbox, _path("runtime"));
        string memory exported = vm.readFile(_path("runtime"));
        assertEq(vm.parseJsonBytes(exported, ".runtime"), runtime_);
        assertEq(vm.parseJsonUint(exported, ".l1ChainId"), _chainId);
        assertEq(vm.parseJsonAddress(exported, ".l1Inbox"), _inbox);
    }

    function _build(uint256 _chainId, address _inbox) private {
        _export(_chainId, _inbox);
        vm.writeFile(
            _path("base"), "{\"config\":{\"chainId\":167001},\"timestamp\":\"0x0\",\"alloc\":{}}"
        );
        string[] memory command = new string[](10);
        command[0] = "python3";
        command[1] = "script/layer2/build_etna_genesis.py";
        command[2] = "--base";
        command[3] = _path("base");
        command[4] = "--runtime";
        command[5] = _path("runtime");
        command[6] = "--output";
        command[7] = _path("genesis");
        command[8] = "--vault-artifact";
        command[9] = "out/layer2/L2FeeVault.sol/L2FeeVault.json";
        vm.ffi(command);
        string memory genesis = vm.readFile(_path("genesis"));
        _install(genesis, _VAULT);
        _install(genesis, _ROOTS);
        _install(genesis, _HISTORY);
    }

    function _path(string memory _kind) private pure returns (string memory) {
        // Foundry runs tests concurrently; filesystem outputs must be per-test.
        return string.concat("deployments/etna-test-", vm.toString(msg.sig), "-", _kind, ".json");
    }

    function _install(string memory _json, address _address) private {
        string memory key = string.concat(".alloc.", vm.toLowercase(vm.toString(_address)), ".");
        vm.etch(_address, vm.parseJsonBytes(_json, string.concat(key, "code")));
        vm.deal(_address, vm.parseJsonUint(_json, string.concat(key, "balance")));
        vm.setNonce(_address, uint64(vm.parseJsonUint(_json, string.concat(key, "nonce"))));
    }
}
