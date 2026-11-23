// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibEtnaVectors } from "./LibEtnaVectors.sol";
import { Vm } from "forge-std/src/Vm.sol";

/// @title LibEtnaVectorAbi
/// @notice Checks the contract-labelled ABI families of `testdata/etna_vectors/vectors.json`:
/// `governance_abi` (calls), `view_abi` (views and their results) and `governance_events`.
/// @dev Shared by the L1 Inbox suites and the L2 staking suite. Every entry carries one of the
/// labels `inbox`, `staking` and `unzen_inbox`, which `labelCounts` requires, so between them the
/// suites read every entry. The checks are forge's assertion cheatcodes, so a caller needs no
/// particular test base.
library LibEtnaVectorAbi {
    /// @dev The forge cheatcode address.
    Vm private constant _VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Requires every entry of the object at `_family` to carry a known label and returns how
    /// many carry each.
    /// @param _json The vectors document.
    /// @param _family The JSON path of the family, e.g. `.governance_abi`.
    /// @return inbox_ The entries labelled `inbox`.
    /// @return staking_ The entries labelled `staking`.
    /// @return unzen_ The entries labelled `unzen_inbox`.
    function labelCounts(
        string memory _json,
        string memory _family
    )
        internal
        pure
        returns (uint256 inbox_, uint256 staking_, uint256 unzen_)
    {
        inbox_ = LibEtnaVectors.countWithContract(_json, _family, "inbox");
        staking_ = LibEtnaVectors.countWithContract(_json, _family, "staking");
        unzen_ = LibEtnaVectors.countWithContract(_json, _family, "unzen_inbox");
        _VM.assertEq(
            inbox_ + staking_ + unzen_,
            LibEtnaVectors.entryCount(_json, _family),
            string.concat(_family, ": every entry names a known contract")
        );
    }

    /// @dev Checks a call entry: it is labelled `_contract`, its signature hashes to its selector,
    /// which is Solidity's `_selector`, and its calldata is `_calldata`.
    /// @param _json The vectors document.
    /// @param _entry The JSON path of the entry, e.g. `.governance_abi.recover`.
    /// @param _contract The expected label.
    /// @param _selector Solidity's selector of the function.
    /// @param _calldata Solidity's encoding of the call with the vector's arguments.
    function assertCall(
        string memory _json,
        string memory _entry,
        string memory _contract,
        bytes4 _selector,
        bytes memory _calldata
    )
        internal
        pure
    {
        _VM.assertEq(
            LibEtnaVectors.stringAt(_json, string.concat(_entry, ".contract")), _contract, _entry
        );
        _VM.assertEq(
            LibEtnaVectors.bytesAt(_json, string.concat(_entry, ".selector")),
            abi.encodePacked(_selector),
            _entry
        );
        string memory signature =
            LibEtnaVectors.stringAt(_json, string.concat(_entry, ".signature"));
        _VM.assertEq(bytes32(bytes4(keccak256(bytes(signature)))), bytes32(_selector), _entry);
        _VM.assertEq(
            LibEtnaVectors.bytesAt(_json, string.concat(_entry, ".calldata")), _calldata, _entry
        );
    }

    /// @dev Checks a view against a deployed contract: `view_abi.<_view>` is labelled `_contract`,
    /// and a static call to `_target` with its calldata succeeds and returns the data of its
    /// result named `_result`.
    /// @param _json The vectors document.
    /// @param _view The view's key in `view_abi`, e.g. `config_hash`.
    /// @param _contract The expected label.
    /// @param _result The name of the result the contract's state should give.
    /// @param _target The contract to call.
    function assertViewResult(
        string memory _json,
        string memory _view,
        string memory _contract,
        string memory _result,
        address _target
    )
        internal
        view
    {
        string memory v = string.concat(".view_abi.", _view, ".");
        _VM.assertEq(LibEtnaVectors.stringAt(_json, string.concat(v, "contract")), _contract, _view);
        bytes memory expected = LibEtnaVectors.bytesAt(
            _json, string.concat(_resultPath(_json, v, _view, _result), "data")
        );
        (bool ok, bytes memory data) =
            _target.staticcall(LibEtnaVectors.bytesAt(_json, string.concat(v, "calldata")));
        _VM.assertTrue(ok, _view);
        _VM.assertEq(data, expected, string.concat(_view, ": ", _result));
    }

    /// @dev Checks a log against `governance_events.<_event>`: the entry is labelled `_contract`
    /// and its signature hashes to its topic0, and the log carries that topic0, the entry's
    /// indexed topics and its data.
    /// @param _json The vectors document.
    /// @param _event The event's key in `governance_events`, e.g. `landed`.
    /// @param _contract The expected label.
    /// @param _log The log.
    function assertEvent(
        string memory _json,
        string memory _event,
        string memory _contract,
        Vm.Log memory _log
    )
        internal
        view
    {
        string memory e = string.concat(".governance_events.", _event, ".");
        _VM.assertEq(
            LibEtnaVectors.stringAt(_json, string.concat(e, "contract")), _contract, _event
        );
        bytes32 topic0 = LibEtnaVectors.bytes32At(_json, string.concat(e, "topic0"));
        _VM.assertEq(
            keccak256(bytes(LibEtnaVectors.stringAt(_json, string.concat(e, "signature")))),
            topic0,
            _event
        );
        _VM.assertEq(_log.topics[0], topic0, _event);
        string memory topics = string.concat(e, "indexed_topics");
        uint256 indexedCount = LibEtnaVectors.lengthAt(_json, topics);
        _VM.assertEq(_log.topics.length, indexedCount + 1, _event);
        for (uint256 t; t < indexedCount; ++t) {
            _VM.assertEq(
                _log.topics[t + 1],
                LibEtnaVectors.bytes32At(_json, string.concat(topics, "[", _VM.toString(t), "]")),
                _event
            );
        }
        _VM.assertEq(_log.data, LibEtnaVectors.bytesAt(_json, string.concat(e, "data")), _event);
    }

    /// @dev Returns the first log of `_logs` whose topic0 is `_topic0`; reverts if there is none.
    /// @param _logs The recorded logs.
    /// @param _topic0 The event's topic0.
    /// @return The log.
    function logWithTopic(
        Vm.Log[] memory _logs,
        bytes32 _topic0
    )
        internal
        pure
        returns (Vm.Log memory)
    {
        for (uint256 i; i < _logs.length; ++i) {
            if (_logs[i].topics.length != 0 && _logs[i].topics[0] == _topic0) return _logs[i];
        }
        revert("no log with that topic0");
    }

    /// @dev Returns the path prefix of the result named `_result` of the `view_abi` entry at `_v`;
    /// reverts if there is none.
    /// @param _json The vectors document.
    /// @param _v The entry's path prefix, e.g. `.view_abi.config_hash.`.
    /// @param _view The view's key, for the revert message.
    /// @param _result The result's name.
    /// @return The result's path prefix.
    function _resultPath(
        string memory _json,
        string memory _v,
        string memory _view,
        string memory _result
    )
        private
        view
        returns (string memory)
    {
        string memory results = string.concat(_v, "results");
        uint256 n = LibEtnaVectors.lengthAt(_json, results);
        for (uint256 i; i < n; ++i) {
            string memory r = LibEtnaVectors.itemAt(results, i);
            string memory name = LibEtnaVectors.stringAt(_json, string.concat(r, "name"));
            if (keccak256(bytes(name)) == keccak256(bytes(_result))) return r;
        }
        revert(string.concat("no result ", _result, " of ", _view));
    }
}
