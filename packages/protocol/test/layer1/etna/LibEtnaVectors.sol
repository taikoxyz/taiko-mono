// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";

/// @title LibEtnaVectors
/// @notice Reads `testdata/etna_vectors/vectors.json`, the Etna vectors the contracts share with
/// taiko-client-rs; see that directory's README for what each section pins and how it is made.
/// @dev Integers are decimal strings in the file; `parseJsonUint` reads them exactly.
library LibEtnaVectors {
    /// @dev The forge cheatcode address.
    Vm private constant _VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev The vectors file, relative to the protocol package root. `foundry.toml` grants read
    /// access to its directory.
    string private constant _PATH = "/../../testdata/etna_vectors/vectors.json";

    /// @dev Returns the vectors file.
    /// @return json_ The JSON document.
    function load() internal view returns (string memory json_) {
        return _VM.readFile(string.concat(_VM.projectRoot(), _PATH));
    }

    /// @dev Reads the unsigned integer at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return The value.
    function uintAt(string memory _json, string memory _key) internal pure returns (uint256) {
        return _VM.parseJsonUint(_json, _key);
    }

    /// @dev Reads the `bytes32` at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return The value.
    function bytes32At(string memory _json, string memory _key) internal pure returns (bytes32) {
        return _VM.parseJsonBytes32(_json, _key);
    }

    /// @dev Reads the address at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return The value.
    function addressAt(string memory _json, string memory _key) internal pure returns (address) {
        return _VM.parseJsonAddress(_json, _key);
    }

    /// @dev Reads the byte string at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return The value.
    function bytesAt(string memory _json, string memory _key) internal pure returns (bytes memory) {
        return _VM.parseJsonBytes(_json, _key);
    }

    /// @dev The domain tag at `_key`: an ASCII name right-padded with zero bytes.
    /// @param _json The vectors document.
    /// @param _key The JSON path of the tag's name.
    /// @return The tag.
    function tagAt(string memory _json, string memory _key) internal pure returns (bytes32) {
        return bytes32(bytes(_VM.parseJsonString(_json, _key)));
    }

    /// @dev Encodes the `committee_config` inputs as the eleven-word `ETNA_PARENT_ANCHOR_V2`
    /// opening, field by field with the Solidity types `IEtnaInbox.land` documents.
    /// @param _json The vectors document.
    /// @return words_ The 352-byte opening.
    function configWords(string memory _json) internal pure returns (bytes memory words_) {
        string memory p = ".committee_config.inputs.";
        words_ = bytes.concat(
            abi.encode(
                tagAt(_json, string.concat(p, "tag")),
                uintAt(_json, string.concat(p, "l2_chain_id")),
                addressAt(_json, string.concat(p, "registry")),
                uintAt(_json, string.concat(p, "vp_unit")),
                uintAt(_json, string.concat(p, "s_min"))
            ),
            abi.encode(
                uint64(uintAt(_json, string.concat(p, "n_max"))),
                uint64(uintAt(_json, string.concat(p, "heartbeat_window"))),
                uint64(uintAt(_json, string.concat(p, "lookahead_epochs"))),
                uint8(uintAt(_json, string.concat(p, "encoding_version"))),
                uint64(uintAt(_json, string.concat(p, "d_max"))),
                uint64(uintAt(_json, string.concat(p, "margin_v")))
            )
        );
    }

    /// @dev The `land_statement` batch outputs as a `LandInput`.
    /// @param _json The vectors document.
    /// @return input_ The batch.
    function landInput(string memory _json)
        internal
        pure
        returns (IEtnaInbox.LandInput memory input_)
    {
        string memory p = ".land_statement.inputs.";
        input_.lastHeight = uint64(uintAt(_json, string.concat(p, "last_height")));
        input_.lastBlockHash = bytes32At(_json, string.concat(p, "last_block_hash"));
        input_.lastStateRoot = bytes32At(_json, string.concat(p, "last_state_root"));
        input_.l1ReferenceBlockNumber =
            uint64(uintAt(_json, string.concat(p, "l1_reference_block_number")));
        input_.forcedInclusionHead =
            uint48(uintAt(_json, string.concat(p, "forced_inclusion_head_after")));
        input_.feeRecipient = addressAt(_json, string.concat(p, "fee_recipient"));
    }

    /// @dev The number of elements of the array at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path of the array.
    /// @return count_ The element count.
    function lengthAt(
        string memory _json,
        string memory _key
    )
        internal
        view
        returns (uint256 count_)
    {
        while (_VM.keyExistsJson(_json, string.concat(_key, "[", _VM.toString(count_), "]"))) {
            ++count_;
        }
    }

    /// @dev The `land_statement` participation input: one part per epoch, in order.
    /// @param _json The vectors document.
    /// @return parts_ The participation.
    function participation(string memory _json)
        internal
        view
        returns (IEtnaInbox.EpochParticipation[] memory parts_)
    {
        string memory p = ".land_statement.inputs.participation";
        parts_ = new IEtnaInbox.EpochParticipation[](lengthAt(_json, p));
        for (uint256 k; k < parts_.length; ++k) {
            string memory e = string.concat(p, "[", _VM.toString(k), "].");
            parts_[k].epoch = uint64(uintAt(_json, string.concat(e, "epoch")));
            parts_[k].committeeHash = bytes32At(_json, string.concat(e, "committee_hash"));
            parts_[k].signedCounts = _uint32Array(_json, string.concat(e, "signed_counts"));
            parts_[k].proposerScores = _uint32Array(_json, string.concat(e, "proposer_scores"));
        }
    }

    /// @dev The members of committee `_index` of `committee_hashes`, in order.
    /// @param _json The vectors document.
    /// @param _index The committee's index.
    /// @return members_ The committee.
    function committee(
        string memory _json,
        uint256 _index
    )
        internal
        view
        returns (IEtnaInbox.CommitteeMember[] memory members_)
    {
        string memory p = string.concat(".committee_hashes[", _VM.toString(_index), "].members");
        members_ = new IEtnaInbox.CommitteeMember[](lengthAt(_json, p));
        for (uint256 i; i < members_.length; ++i) {
            string memory m = string.concat(p, "[", _VM.toString(i), "].");
            members_[i] = IEtnaInbox.CommitteeMember({
                bondId: uint32(uintAt(_json, string.concat(m, "bond_id"))),
                activeFromL1: uint64(uintAt(_json, string.concat(m, "active_from_l1"))),
                effStake: uintAt(_json, string.concat(m, "eff_stake"))
            });
        }
    }

    /// @dev Registry entry `_index` of `registry_entries`.
    /// @param _json The vectors document.
    /// @param _index The entry's index (its bond id).
    /// @return entry_ The entry.
    function registryEntry(
        string memory _json,
        uint256 _index
    )
        internal
        pure
        returns (IEtnaStakingRegistry.Entry memory entry_)
    {
        string memory p = string.concat(".registry_entries.entries[", _VM.toString(_index), "].");
        entry_.pubkey = bytes32At(_json, string.concat(p, "pubkey"));
        entry_.effStake = uintAt(_json, string.concat(p, "eff_stake"));
        entry_.activeFromL1 = uint64(uintAt(_json, string.concat(p, "active_from_l1")));
        entry_.exitEffectiveL1 = uint64(uintAt(_json, string.concat(p, "exit_effective_l1")));
        entry_.lastHeartbeatAt = uint64(uintAt(_json, string.concat(p, "last_heartbeat_at")));
        entry_.lastHeartbeatSeq = uint64(uintAt(_json, string.concat(p, "last_heartbeat_seq")));
    }

    /// @dev The packed field `_field` of the storage word `_word` described at `_packing` (e.g.
    /// `.layout.inbox.packing.activation_packed`).
    /// @param _json The vectors document.
    /// @param _packing The JSON path of the word's packing table.
    /// @param _field The field's name in that table.
    /// @param _word The storage word.
    /// @return The field, read low-order-first at its offset and width.
    function fieldOf(
        string memory _json,
        string memory _packing,
        string memory _field,
        uint256 _word
    )
        internal
        pure
        returns (uint256)
    {
        string memory p = string.concat(_packing, ".", _field, ".");
        uint256 offset = uintAt(_json, string.concat(p, "offset"));
        uint256 bits = uintAt(_json, string.concat(p, "bits"));
        return (_word >> offset) & ((1 << bits) - 1);
    }

    /// @dev `_word` with the field `_field` described at `_packing` set to `_value`.
    /// @param _json The vectors document.
    /// @param _packing The JSON path of the word's packing table.
    /// @param _field The field's name in that table.
    /// @param _word The storage word.
    /// @param _value The new field value; must fit the field.
    /// @return The updated word.
    function withField(
        string memory _json,
        string memory _packing,
        string memory _field,
        uint256 _word,
        uint256 _value
    )
        internal
        pure
        returns (uint256)
    {
        string memory p = string.concat(_packing, ".", _field, ".");
        uint256 offset = uintAt(_json, string.concat(p, "offset"));
        uint256 mask = (1 << uintAt(_json, string.concat(p, "bits"))) - 1;
        require(_value <= mask, "field value too wide");
        return (_word & ~(mask << offset)) | (_value << offset);
    }

    /// @dev Reads the decimal-string array at `_key` as uint32 values.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return values_ The values.
    function _uint32Array(
        string memory _json,
        string memory _key
    )
        private
        pure
        returns (uint32[] memory values_)
    {
        uint256[] memory raw = _VM.parseJsonUintArray(_json, _key);
        values_ = new uint32[](raw.length);
        for (uint256 i; i < raw.length; ++i) {
            values_[i] = uint32(raw[i]);
        }
    }
}
