// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    FmspcTcbHelper,
    TCBLevelsObj,
    TDXModule,
    TcbId,
    TcbInfoBasic,
    TcbInfoJsonObj
} from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";
import "forge-std/src/Script.sol";

/// @title EncodeSgxFmspcTcbStorage
/// @notice Encodes signed SGX TCBInfo collateral into AutomataDaoStorage attest payloads.
/// @dev This is intentionally an offline encoder. The normal Automata DAO upsert path validates
/// the Intel signature on-chain, but Hoodi's transaction gas cap is too low for current SGX TCBInfo
/// parsing. The surrounding shell script still fetches the signed Intel collateral; this script only
/// builds the exact storage records that AutomataFmspcTcbDaoVersioned would have written.
contract EncodeSgxFmspcTcbStorage is Script {
    bytes4 private constant FMSPC_TCB_MAGIC = 0xbb69b29c;

    function run() external {
        string memory tcbInfoPath = vm.envString("TCB_INFO_PATH");
        uint32 expectedEval = uint32(vm.envUint("TCB_EVAL"));
        string memory outDir = vm.envString("OUT_DIR");

        string memory tcbInfoStr = vm.readFile(tcbInfoPath);
        FmspcTcbHelper helper = new FmspcTcbHelper();

        (
            TcbInfoBasic memory basic,
            string memory tcbLevelsString,
            string memory tdxModuleString,
            string memory tdxModuleIdentitiesString
        ) = helper.parseTcbString(tcbInfoStr);

        require(basic.id == TcbId.SGX, "only SGX supported");
        require(basic.version == 3, "expected SGX TCBInfo v3");
        require(basic.evaluationDataNumber == expectedEval, "TCB eval mismatch");

        bytes32 key = _fmspcTcbKey(basic, expectedEval);
        vm.writeFile(string.concat(outDir, "/tcb_key.hex"), vm.toString(key));
        vm.writeFile(
            string.concat(outDir, "/tcb_data.hex"),
            vm.toString(
                _attestationData(
                    helper,
                    tcbInfoStr,
                    vm.parseBytes(vm.envString("TCB_SIGNATURE")),
                    basic,
                    tcbLevelsString
                )
            )
        );
        vm.writeFile(
            string.concat(outDir, "/tcb_sha256.hex"), vm.toString(sha256(bytes(tcbInfoStr)))
        );
        _writeSidecarFiles(
            outDir,
            key,
            helper.generateFmspcTcbContentHash(
                basic, tcbLevelsString, tdxModuleString, tdxModuleIdentitiesString
            ),
            basic.issueDate,
            basic.nextUpdate,
            expectedEval
        );
    }

    function _attestationData(
        FmspcTcbHelper helper,
        string memory tcbInfoStr,
        bytes memory signature,
        TcbInfoBasic memory basic,
        string memory tcbLevelsString
    )
        private
        view
        returns (bytes memory)
    {
        TCBLevelsObj[] memory levels = helper.parseTcbLevels(basic.version, tcbLevelsString);
        bytes[] memory encodedLevelItems = new bytes[](levels.length);
        for (uint256 i; i < levels.length; ++i) {
            encodedLevelItems[i] = helper.tcbLevelsObjToBytes(levels[i]);
        }

        TDXModule memory module;
        return abi.encode(
            basic,
            module,
            bytes(""),
            abi.encode(encodedLevelItems),
            TcbInfoJsonObj({ tcbInfoStr: tcbInfoStr, signature: signature })
        );
    }

    function _fmspcTcbKey(
        TcbInfoBasic memory basic,
        uint32 expectedEval
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                FMSPC_TCB_MAGIC, uint8(basic.id), basic.fmspc, basic.version, expectedEval
            )
        );
    }

    function _writeSidecarFiles(
        string memory outDir,
        bytes32 key,
        bytes32 contentHash,
        uint64 issueDate,
        uint64 nextUpdate,
        uint32 expectedEval
    )
        private
    {
        bytes32 issueEvaluationKey = keccak256(abi.encodePacked(key, "tcbIssueEvaluation"));
        bytes32 contentHashKey = keccak256(abi.encodePacked(key, "fmspcTcbContentHash"));
        uint256 issueEvaluationSlot =
            (uint256(issueDate) << 192) | (uint256(nextUpdate) << 128) | uint256(expectedEval);

        vm.writeFile(string.concat(outDir, "/issue_eval_key.hex"), vm.toString(issueEvaluationKey));
        vm.writeFile(
            string.concat(outDir, "/issue_eval_data.hex"),
            vm.toString(abi.encode(issueEvaluationSlot))
        );
        vm.writeFile(string.concat(outDir, "/content_hash_key.hex"), vm.toString(contentHashKey));
        vm.writeFile(
            string.concat(outDir, "/content_hash_data.hex"),
            vm.toString(abi.encodePacked(contentHash))
        );
    }
}
